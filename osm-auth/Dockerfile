FROM python:3.11-alpine

EXPOSE 80

WORKDIR /code

COPY ./requirements.txt /code/requirements.txt

RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY ./osm_auth.py /code/osm_auth.py

CMD ["uvicorn", "osm_auth:app", "--proxy-headers", "--host", "0.0.0.0", "--port", "80"]
