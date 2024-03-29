import os
from datetime import timedelta, datetime
from tempfile import TemporaryDirectory
from typing import Any, TypedDict
from urllib.request import urlretrieve

import geopandas as gpd
import pandas as pd

from airflow import DAG, Dataset
from osm_bjk.fetch_dataframe_operator import FetchDataframeOperator


class DAGArgs(TypedDict):
    schedule_interval: timedelta
    start_date: datetime
    catchup: bool
    max_active_runs: int
    default_args: dict
    tags: list[str]


args: DAGArgs = dict(
    schedule_interval=timedelta(days=28),
    start_date=datetime(2023, 9, 16, 21, 30),
    catchup=False,
    max_active_runs=1,
    default_args=dict(
        depends_on_past=False,
        email=["jan@dalheimer.de"],
        email_on_failure=True,
        email_on_retry=False,
        retries=1,
        retry_delay=timedelta(minutes=5),
    ),
    tags=["provider:Gävle kommun"],
)


def parse_gavle_datetime(v: Any) -> datetime | None:
    if str(v) == "nan" or v is None:
        return None
    v = str(v).split(".")[0]
    return datetime.strptime(v, "%Y%m%d" if len(v) == 8 else "%Y%m%d%H%M%S")


datasets = [
    ("Badplatser och badanläggningar", "badplatser", "237", "234"),
    ("Cykelpumpar", "cykelpumpar", "242", "239"),
    ("Grusytor", "grusytor", "284", "281"),
    ("Isbanor", "isbanor", "299", "291"),
    ("Livräddningsutrustning", "livraddningsutrustning", "325", "312"),
    ("Parkmöbler", "parkmobler", "247", "244"),
    ("Pulkabackar", "pulkabackar", "297", "292"),
    ("Trädskötsel", "tradskotsel", "289", "286"),
    ("Parkeringsautomater", "parkeringsautomater", "364", "231"),
    ("Utegym", "utegym", "360", "357"),
    ("Aktivitetsytor", "aktivitetsytor", "468", "465"),
    ("Papperskorgar", "papperskorgar", "273", "270"),
    ("Idrott och motion", "idrottmotion", "509", "506"),
    ("Baskarta Adresser", "adresser", "88", "45"),
    ("Hundrastgårdar", "hundrastgardar", "85", "24"),
    ("Lekplatser", "lekplatser", "83", "30"),
    ("Historiska skyltar", "historiskaskyltar", "369", "366"),
    ("Busshållplatser", "busshalplatser", "138", "135"),
    ("Busslinjer", "busslinjer", "133", "130"),
    ("Offentliga toaletter", "offentligatoaletter", "150", "147"),
    ("Återvinningsstationer och återvinningscentraler", "atervinning", "162", "159"),
    ("Cykelparkeringsplatser", "cykelparkeringsplatser", "179", "166"),
    ("Gästhamnar och naturhamnar", "gastochnaturhamnar", "202", "199"),
]

for name, identifier, resource, entry in datasets:
    with DAG(
        f"gavlekommun-{identifier}",
        description=f"Hämtar {name} från Gävle kommun",
        **args,
    ):
        FetchDataframeOperator(
            task_id="fetch",
            fetch=f"https://catalog.gavle.se/store/1/resource/{resource}",
            provider="Gävle kommun",
            dataset=name,
            outlets=[Dataset(f"psql://upstream/gavlekommun/{identifier}")],
        )


with DAG(
    f"gavlekommun-skolor",
    description=f"Hämtar Kommunala och privata skolor från Gävle kommun",
    **args,
):

    def fetch_skolor(*_args, **_kwargs):
        df = pd.read_csv("https://catalog.gavle.se/store/1/resource/38")
        geom = gpd.points_from_xy(df.long, df.lat, crs="EPSG:4326")
        return gpd.GeoDataFrame(df, geometry=geom).set_index("id")

    FetchDataframeOperator(
        task_id="fetch",
        fetch=fetch_skolor,
        provider="Gävle kommun",
        dataset="Kommunala och privata skolor",
        outlets=[Dataset("psql://upstream/gavlekommun/skolor")],
    )


class FetchExtract:
    def __init__(self, resource: str, member: str):
        self.resource = resource
        self.member = member

    def __call__(self, *_args, **_kwargs):
        with TemporaryDirectory() as directory:
            zipname = os.path.join(directory, "data.zip")
            url = f"https://catalog.gavle.se/store/1/resource/{self.resource}"
            print(f"Downloading {url}...")
            urlretrieve(url, zipname)
            print(f"Reading {self.member}...")
            df = gpd.read_file(f"zip://{zipname}!{self.member}")
            if "UPDDATUM" in df:
                df["bjk__updatedAt"] = df.UPDDATUM.apply(parse_gavle_datetime)
            return df


with DAG(
    f"gavlekommun-byggnader",
    description=f"Hämtar Baskarta Byggnader från Gävle kommun",
    **args,
):
    for identifier, file in [
        ("byggnad", "baskarta_byggnad.json"),
        ("byggnadsbeteckning", "baskarta_byggnadsbeteckning.json"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{identifier}",
            fetch=FetchExtract("76", file),
            provider="Gävle kommun",
            dataset=f"Baskarta Byggnader ({identifier})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/byggnader-{identifier}")],
        )

with DAG(
    f"gavlekommun-parkeringar",
    description=f"Hämtar Parkeringar från Gävle kommun",
    **args,
):
    for identifier, file in [
        ("parkeringsplatser", "Parkering_L.json"),
        ("parkeringszoner", "Parkering_A.json"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{identifier}",
            fetch=FetchExtract("115", file),
            provider="Gävle kommun",
            dataset=f"Parkeringar ({identifier})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/parkeringar-{identifier}")],
        )

with DAG(
    f"gavlekommun-tillganglighet",
    description=f"Hämtar Tillgänglighet från Gävle kommun",
    **args,
):
    for name, file in [
        ("inventerade områden", "inventerade_omraden"),
        ("busshållplatser", "busshallplatser"),
        ("bänkar", "bankar"),
        ("huvudgångstråk", "huvudgangstrak"),
        ("passager", "passager"),
        ("parkering för rörelsehindrad", "parkering_rorelsehindrad"),
        ("belysning", "belysning"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{file}",
            fetch=FetchExtract("337", f"tillganglighet_{file}.json"),
            provider="Gävle kommun",
            dataset=f"Tillgänglighet ({name})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/tillganglighet-{file}")],
        )

with DAG(f"gavlekommun-cykelplan", description=f"Hämtar Cykelplan från Gävle kommun", **args):
    for name, file in [
        ("befintligt cykelnät", "Befintligt_Cykelnat"),
        ("målpunkter", "Malpunkter"),
        ("ny cykelbana", "Ny_Cykelbana"),
        ("ny passage", "Ny_Passage"),
        ("skolor", "Skolor"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{file.lower()}",
            fetch=FetchExtract("443", f"Cykelplan_{file}.json"),
            provider="Gävle kommun",
            dataset=f"Cykelplan ({name})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/cykelplan-{file.lower()}")],
        )

with DAG(
    f"gavlekommun-detaljer",
    description=f"Hämtar Baskarta Detaljer från Gävle kommun",
    **args,
):

    def fetch_detaljer(*_args, **_kwargs):
        with TemporaryDirectory() as directory:
            zipname = os.path.join(directory, "data.zip")
            url = "https://catalog.gavle.se/store/1/resource/96"
            print(f"Downloading {url}...")
            urlretrieve(url, zipname)
            print(f"Reading linjeobjekt...")
            df_linje = gpd.read_file(f"zip://{zipname}!baskarta_linjeobjekt.json")
            print(f"Reading punktobjekt...")
            df_punkt = gpd.read_file(f"zip://{zipname}!baskarta_punktobjekt.json")
            df = gpd.GeoDataFrame(pd.concat([df_linje, df_punkt], ignore_index=True), crs=df_linje.crs)
            df["bjk__updatedAt"] = df.UPDDATUM.apply(parse_gavle_datetime)
            return df

    FetchDataframeOperator(
        task_id=f"fetch",
        fetch=fetch_detaljer,
        provider="Gävle kommun",
        dataset=f"Baskarta Detaljer",
        outlets=[Dataset(f"psql://upstream/gavlekommun/detaljer")],
    )

with DAG(
    f"gavlekommun-motionsspar",
    description=f"Hämtar Motionsspår från Gävle kommun",
    **args,
):
    for name, file in [
        ("motionsspår", "motionsspar"),
        ("rastplatser", "Rastplatser"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{file.lower()}",
            fetch=FetchExtract("78", f"{file}.json"),
            provider="Gävle kommun",
            dataset=f"Motionsspår ({name})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/motionsspar-{file.lower()}")],
        )

with DAG(
    f"gavlekommun-vatten",
    description=f"Hämtar Baskarta Vatten från Gävle kommun",
    **args,
):
    for name, file in [
        ("strandlinje", "strandlinje"),
        ("vatten", "vatten"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{file.lower()}",
            fetch=FetchExtract("92", f"baskarta_{file}.json"),
            provider="Gävle kommun",
            dataset=f"Baskarta Vatten ({name})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/vatten-{file.lower()}")],
        )

    def fetch_vattenobjekt(*_args, **_kwargs):
        with TemporaryDirectory() as directory:
            zipname = os.path.join(directory, "data.zip")
            url = "https://catalog.gavle.se/store/1/resource/92"
            print(f"Downloading {url}...")
            urlretrieve(url, zipname)
            print(f"Reading linjeobjekt...")
            df_linje = gpd.read_file(f"zip://{zipname}!baskarta_vattenobjekt_linje.json")
            print(f"Reading punktobjekt...")
            df_punkt = gpd.read_file(f"zip://{zipname}!baskarta_vattenobjekt_punkt.json")
            print(f"Reading ytaobjekt...")
            df_yta = gpd.read_file(f"zip://{zipname}!baskarta_vattenobjekt_yta.json")
            df = gpd.GeoDataFrame(
                pd.concat([df_linje, df_punkt, df_yta], ignore_index=True),
                crs=df_linje.crs,
            )
            df["bjk__updatedAt"] = df.UPDDATUM.apply(parse_gavle_datetime)
            return df

    FetchDataframeOperator(
        task_id=f"fetch-vattenobjekt",
        fetch=fetch_vattenobjekt,
        provider="Gävle kommun",
        dataset=f"Baskarta Vatten",
        outlets=[Dataset(f"psql://upstream/gavlekommun/vatten-vattenobjekt")],
    )

with DAG(f"gavlekommun-vagar", description=f"Hämtar Baskarta Vägar från Gävle kommun", **args):
    for name, file in [
        ("järnväg", "jarnvag"),
        ("väg", "vag"),
    ]:
        FetchDataframeOperator(
            task_id=f"fetch-{file.lower()}",
            fetch=FetchExtract("94", f"baskarta_{file}.json"),
            provider="Gävle kommun",
            dataset=f"Baskarta Vägar ({name})",
            outlets=[Dataset(f"psql://upstream/gavlekommun/vagar-{file.lower()}")],
        )
