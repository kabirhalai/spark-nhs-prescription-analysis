FROM python:3.12-slim

ARG SPARK_VERSION=3.5.4
ARG HADOOP_VERSION=3

ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV SPARK_HOME=/opt/spark
ENV PATH="${PATH}:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${JAVA_HOME}/bin"
ENV PYSPARK_PYTHON=python3
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Download and install Spark
RUN curl -fsSL "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" \
    | tar -xz -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark

WORKDIR /workspace

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY conf/spark-defaults.conf ${SPARK_HOME}/conf/spark-defaults.conf
COPY conf/log4j2.properties ${SPARK_HOME}/conf/log4j2.properties

RUN python3 -c "from pyspark.sql import SparkSession; SparkSession.builder.config('spark.jars.packages', 'io.delta:delta-spark_2.12:3.3.0').getOrCreate().stop()"

EXPOSE 8888 4040 4041

CMD ["jupyter", "lab", \
     "--ip=0.0.0.0", \
     "--port=8888", \
     "--no-browser", \
     "--allow-root", \
     "--notebook-dir=/workspace"]
