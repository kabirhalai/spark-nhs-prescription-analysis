# NHS Prescription Analysis — Cloud-Native PySpark Pipeline

An end-to-end data engineering pipeline that ingests, transforms, and analyses **10 million+ rows** of NHS GP prescription data using PySpark, Delta Lake, and Azure infrastructure — with a fully Dockerised local development environment for rapid iteration.

---

## Architecture Overview

```
data.gov.uk (NHS)
      │
      ▼
┌─────────────────────┐
│  Ingestion (main.py) │  Playwright scraper + parallel CSV download
│  → Raw storage       │  MinIO (local) / Azure Data Lake Storage (cloud)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Bronze Layer        │  Raw CSV → Delta Lake (schema enforcement)
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Silver Layer        │  PySpark transformations, cleaning, deduplication
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Gold Layer          │  Aggregated marts ready for analysis / BI
└─────────────────────┘
          │
          ▼
   Azure Databricks
   (full dataset run)
```

**Medallion architecture** (Bronze → Silver → Gold) implemented with Delta Lake for ACID transactions, schema evolution, and time travel.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Processing | Apache Spark 3.5.4, PySpark |
| Storage format | Delta Lake 3.3.0 |
| Cloud storage | Azure Data Lake Storage (ADLS) |
| Cloud compute | Azure Databricks |
| Infrastructure | Terraform (Azure provisioning) |
| Local dev | Docker, JupyterLab 4.x |
| Ingestion | Python, Playwright, boto3 |
| Runtime | Python 3.12, Java 17 (OpenJDK) |

---

## Dataset

**Source:** [NHS Prescribing by GP Practice — Presentation Level](https://www.data.gov.uk/dataset/176ae264-2484-4afe-a297-d51798eb8228/prescribing-by-gp-practice-presentation-level)

- Monthly CSV files published by NHS England
- Covers GP-level prescribing data across all practices in England
- Pipeline processes data across configurable year ranges (currently 2015–2016 for local dev, full dataset on Azure)
- ~10 million rows at full scale

---

## Ingestion Pipeline

`main.py` handles the full ingestion flow:

1. **Scrape** — Playwright headless browser navigates the NHS data portal and extracts all CSV download links (including paginated "Show More" results)
2. **Parse** — Links are organised into a `{year: {month: {presentation_level: url}}}` structure
3. **Download & Upload** — CSVs are streamed directly to storage (no local disk write) using `ThreadPoolExecutor` with 8 parallel workers

```bash
# Run ingestion for a specific year range
python main.py
```

Configure year range in `main.py`:

```python
download_and_upload_files_for_year_range(links_by_year, start_year=2015, end_year=2016)
```

---

## Cloud Deployment (Azure)

Infrastructure is provisioned via Terraform in the `terraform/` directory:

- **Azure Data Lake Storage (ADLS)** — raw and processed data storage
- **Azure Databricks** — full-scale PySpark execution and notebook environment
- **Databricks Workflows** — scheduled pipeline runs

```bash
cd terraform
terraform init
terraform apply
```

The same notebooks developed locally run on Databricks against the full 10M+ row dataset stored in ADLS.

---

## Status

| Component | Status |
|---|---|
| Ingestion pipeline | ✅ Complete |
| Bronze layer (raw → Delta) | ✅ Complete |
| Silver layer (transformations) | 🔄 In progress |
| Gold layer (aggregated marts) | 🔄 In progress |
| Azure Databricks deployment | 🔄 In progress |
| Terraform infra | ✅ Complete |

---

## Related

- [Data Engineering Zoomcamp](https://github.com/DataTalksClub/data-engineering-zoomcamp) — curriculum this project was developed alongside
- [NHS Open Data Portal](https://www.data.gov.uk/)
