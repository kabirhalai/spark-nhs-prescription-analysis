# PySpark + Delta Lake — Local Docker Dev

| Component    | Version |
|------------- |---------|
| Python       | 3.12    |
| Apache Spark | 3.5.4   |
| Delta Lake   | 3.3.0   |
| JupyterLab   | 4.x     |
| Java         | 17 (OpenJDK) |

## Quick Start

```bash
# Build & start
docker compose up --build

# Open JupyterLab (token: dev)
open http://localhost:8888

# Spark UI (once a session is running)
open http://localhost:4040
```

## Structure

```
.
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── .env                    # JUPYTER_TOKEN, ports
├── conf/
│   ├── spark-defaults.conf # Delta extensions pre-configured
│   └── log4j2.properties   # Quiet logging for dev
├── notebooks/
│   └── 01_delta_lake_intro.ipynb
├── scripts/
│   └── spark_session.py    # Shared SparkSession factory
├── data/                   # Raw input data (gitignored)
└── delta-tables/           # Delta table storage (gitignored)
```

## Using the SparkSession helper

```python
import sys
sys.path.insert(0, '/workspace/scripts')
from spark_session import get_spark

spark = get_spark()
```

## Changing resources

Edit `conf/spark-defaults.conf`:
```
spark.driver.memory    4g
spark.executor.memory  4g
```

Or pass at session creation:
```python
spark = get_spark().config("spark.driver.memory", "4g")
```

## Stop

```bash
docker compose down
```
