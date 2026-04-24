FROM quay.io/jupyter/pyspark-notebook:spark-3.5.0

USER root

WORKDIR /workspace

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Jupyter's PySpark image sets SPARK_HOME to /usr/local/spark
COPY conf/spark-defaults.conf /usr/local/spark/conf/spark-defaults.conf
COPY conf/log4j2.properties /usr/local/spark/conf/log4j2.properties

# Switch back to the default Jupyter user
USER $NB_UID