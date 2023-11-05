#!/usr/bin/env bash

helm upgrade --install airflow apache-airflow/airflow -n osm-airflow -f airflow-values.yaml
