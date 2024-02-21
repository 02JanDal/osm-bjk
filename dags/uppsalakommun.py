from datetime import timedelta, datetime
from typing import TypedDict

import geopandas as gpd

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
    start_date=datetime(2024, 2, 20, 19, 30),
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
    tags=["provider:Uppsala kommun"],
)

datasets = [
    ("Friluftsområden och naturreservat", "friluftsomraden-naturreservat", "7f4010a678244813829db66246dfadbe", "55"),
    # ('Stomnät - plan', 'stomnät - plan', 'cf87d9db0e124e6680851d7d655edab9', '0'),
    # ('Stomnät - höjd', 'stomnät - höjd', '06f816f415904b5bbd3d83869e71358a', '1'),
    # ('Tillägg detaljplan - tolkade', 'tillägg detaljplan - tolkade', '261d4cbc686c478eb52fd26c6241342b', '121'),
    # ('Områdesbestämmelser - tolkade', 'områdesbestämmelser - tolkade', 'ae95efc2d33949e8b4f59b50a977db08', '123'),
    # ('Promenadstråk - Stråket kvinnliga konstnärer', 'promenadstråk - stråket kvinnliga konstnärer', '3d1d3ed6fd5146f097a3857a15dbba94', '5'),
    # ('Promenadstråk - Stråket för platsens historia', 'promenadstråk - stråket för platsens historia', '92ab14a0c5d241c3bcec8dfec4500f24', '6'),
    # ('Promenadstråk - Fredsstråket', 'promenadstråk - fredsstråket', '274be3ed56c74546b490a967977525cf', '0'),
    # ('Planområden', 'planområden', '97e300e531e341fa9672f01f73404c76', '122'),
    ("Återvinningscentraler", "atervinningscentraler", "e892a61c3e144d8ab4857395b141766d", "19"),
    # ('NYKO 2017 - nivå 3', 'nyko 2017 - nivå 3', 'e81f0b906c1741fa84c0e9c77164d34b', '75'),
    # ('NYKO 2017 - nivå 5', 'nyko 2017 - nivå 5', 'e97d3fbc9f0341a89767a21d40e08460', '77'),
    # ('NYKO 2017 - nivå 4', 'nyko 2017 - nivå 4', '4b5abbbe455c453881501745ea3df169', '76'),
    # ('NYKO 2017 - nivå 2', 'nyko 2017 - nivå 2', '64f900feef1f4382bbb714b8f440b841', '74'),
    # ('NYKO 2017 - nivå 1', 'nyko 2017 - nivå 1', '2537b7e32e86417f9ad9f26ee8ccfe9e', '73'),
    ("Vandringsleder", "vandringsleder", "0d73213bf4c54c0e899a3c11eefdf860", "80"),
    ("Utegym", "utegym", "e1e907d3f9c1430e8c7c23d5a94680a9", "82"),
    ("Skidspår", "skidspar", "70d68ebd26d2431ba4f85a032fa6062a", "60"),
    ("Ridstigar", "ridstigar", "b819f0609959415daa0a1b96958fd8b9", "61"),
    ("Motionsspår", "motionsspar", "e037a040c42a403c9eb7b56ad881660c", "86"),
    ("Linnéstigar", "linnestigar", "67535a1e0dbe441ba251114e1b013779", "65"),
    ("Lekplatser", "lekplatser", "67c02b41524b45ad9d70c86fdd12131f", "66"),
    ("Badplatser", "badplatser", "aadc5420e8884d32b2efe0d10fbfdfe5", "70"),
    ("Fågeltorn och utkiksplatser", "fageltorn-utkiksplatser", "8df41ee8e7b9438ebe47d7ca34148463", "69"),
    ("Vindskydd", "vindskydd", "d6c0b05b7ad54e5596d54f3d83da2cc7", "56"),
    ("Skridskoleder", "skridskoleder", "619bf85e3b5c4826aa4bdd2b585e50d5", "59"),
    ("Raststugor", "raststugor", "ef99e21553114edeb02e3c06bc499213", "62"),
    ("Områdesleder", "omradesleder", "4b4ec89b57ae43508412e8bdc455d5af", "63"),
    ("Mountainbikeleder", "mountainbikeleder", "99fc3cc729b04b50b7146ecbf5aac7e9", "64"),
    ("Grillplatser", "grillplatser", "635e669c84724263b090259ab6ad0572", "68"),
]

for name, identifier, dataset, layer in datasets:
    with DAG(f"uppsalakommun-{identifier}", description=f"Hämtar {name} från Uppsala Kommun", **args):

        def fetcher(*args, **kwargs):
            return (
                gpd.read_file(f"https://opendata.uppsala.se/api/download/v1/items/{dataset}/geojson?layers={layer}")
                .astype({"OBJECTID": "str"})
                .set_index("OBJECTID")
            )

        FetchDataframeOperator(
            task_id="fetch",
            fetch=fetcher,
            provider="Uppsala kommun",
            dataset=name,
            outlets=[Dataset(f"psql://upstream/uppsalakommun/{identifier}")],
        )
