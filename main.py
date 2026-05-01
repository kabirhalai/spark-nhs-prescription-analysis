import time
import boto3
import os
import requests
from concurrent.futures import ThreadPoolExecutor
from botocore.client import ClientError
from botocore.config import Config
from collections import defaultdict
from playwright.sync_api import sync_playwright
from dotenv import load_dotenv


load_dotenv()

LINK = "https://www.data.gov.uk/dataset/176ae264-2484-4afe-a297-d51798eb8228/prescribing-by-gp-practice-presentation-level"
RAW_BUCKET_NAME = os.getenv('AWS_RAW_BUCKET_NAME')

class S3Client:
    def __init__(self):
        self.client = boto3.client(
            's3',
            endpoint_url='http://localhost:9000',
            aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
            aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
            config=Config(signature_version='s3v4'),
            region_name=os.getenv('AWS_REGION')
        )

        self.ensure_bucket_exists(RAW_BUCKET_NAME)

    def ensure_bucket_exists(self, bucket_name):
        try:
            self.client.head_bucket(Bucket=bucket_name)
        except ClientError:
            print(f"Bucket {bucket_name} does not exist. Creating bucket.")
            self.client.create_bucket(Bucket=bucket_name)

def extract_file_links():
    extracted_links = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(LINK)

        def extract_file_links():
            all_file_links = page.query_selector_all(".govuk-link")
            for file_link in all_file_links:
                text = file_link.inner_text()
                url = file_link.get_attribute("href")
                extracted_links.append((text, url))
        
        # Click the 'Show More' button
        next_button = page.query_selector("section.dgu-datalinks > button")
        if next_button:
            next_button.click()
            extract_file_links()
        browser.close()
    return extracted_links

def process_raw_links_into_file_dict(raw_links):
    file_name_to_link_dict = {i[0].splitlines()[1]: i[1] for i in raw_links 
                              if ('Download' in i[0]) and ('Format: CSV,' in i[0])}
    
    temporal_key_dict = defaultdict(lambda: defaultdict(lambda: defaultdict(str)))
    for file_name, link in file_name_to_link_dict.items():
        parts = file_name.strip().split()
        month, year = parts[0].strip(), parts[1].strip()
        presentation_level = ' '.join(parts[2:]).strip()
        print(f"Extracted - Year: {year}, Month: {month}, Presentation Level: {presentation_level}, Link: {link}")
        try:
            temporal_key_dict[int(year)][month][presentation_level] = link
        except ValueError:
            print(f"Skipping file with invalid year format: {file_name}")
            continue
    return temporal_key_dict

def ingest_file_for_year_month(s3_client,year,month,link_dict):
    for presentation_level, link in link_dict.items():
        print(f"Streaming {presentation_level} for {month} {year} from {link}")
        file_name = f"{'_'.join(presentation_level.split(' '))}.csv"
        cloud_path = f"{year}/{month}/{file_name}"

        try:
            tic = time.perf_counter()
            response = requests.get(link, stream=True)
            response.raise_for_status()
            response.raw.decode_content = True
            s3_client.client.upload_fileobj(response.raw, RAW_BUCKET_NAME, cloud_path)
            toc = time.perf_counter()
            print(f"Uploaded {presentation_level} for {month} {year} to S3 in {toc - tic:0.2f} seconds")
        except Exception as e:
            print(f"Error on {cloud_path}: {e}")



def download_and_upload_files_for_year_range(links_by_year, start_year, end_year):
    s3_client = S3Client()

    download_range = [(year,month,links_by_year[year][month]) for year in range(start_year,end_year+1) for month in links_by_year[year]]

    with ThreadPoolExecutor(max_workers=8) as executor:
        executor.map(lambda f: ingest_file_for_year_month(s3_client,*f), download_range)

def main():
    raw_links = extract_file_links()
    
    links_by_year = process_raw_links_into_file_dict(raw_links)

    try:
        download_and_upload_files_for_year_range(links_by_year, 2015, 2016)
    except ValueError as e:
        print("Error in downloading files:", e)


if __name__ == "__main__":
    main()