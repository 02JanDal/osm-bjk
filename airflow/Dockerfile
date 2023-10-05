FROM apache/airflow:slim-2.7.0-python3.10

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         pyosmium osm2pgsql \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
USER airflow

RUN pip install --no-cache-dir \
	"apache-airflow==${AIRFLOW_VERSION}" \
	apache-airflow-providers-postgres \
	apache-airflow-providers-discord \
	apache-airflow-providers-ftp \
	apache-airflow-providers-http \
	apache-airflow-providers-sftp \
  apache-airflow-providers-cncf-kubernetes \
	airflow-code-editor black \
	overpy osmapi osmium \
	gtfs_kit \
	pandas geopandas shapely fiona \
  psycopg \
	requests ujson
