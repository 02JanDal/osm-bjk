from datetime import datetime, timedelta

import geopandas
from airflow import DAG, Dataset
from airflow.decorators import task
from airflow.models import Variable, TaskInstance
from airflow.sensors.base import PokeReturnValue

from osm_bjk.fetch_dataframe_operator import FetchDataframeOperator
from osm_bjk.lantmateriet import lantmateriet, lm_order_start_delivery, lm_order_get_delivery, lm_order_get_files, \
    FileData
from osm_bjk.licenses import CC0_1_0


from typing import TYPE_CHECKING, TypedDict, Literal
if TYPE_CHECKING:
    from typing import NotRequired


class Sublayer(TypedDict):
    name: str
    slug: "NotRequired[str]"


class Layer(TypedDict):
    name: str
    sublayers: list[Sublayer]


LAYERS = [
    Layer(name="Administrativ indelning", sublayers=[Sublayer(name="Administrativ gräns"), Sublayer(name="Riksröse")]),
    Layer(name="Anläggningsområde", sublayers=[Sublayer(name="Anläggningsområde"), Sublayer(name="Anläggningsområdespunkt"), Sublayer(name="Start- och landningsbana", slug="start_landningsbana"), Sublayer(name="Flygplatsområde"), Sublayer(name="Flygplatspunkt")]),
    Layer(name="Byggnadsverk", sublayers=[Sublayer(name="Byggnad"), Sublayer(name="Byggnadsanläggningslinje"), Sublayer(name="Byggnadsanläggningspunkt"), Sublayer(name="Byggnadspunkt")]),
    Layer(name="Hydrografi", sublayers=[Sublayer(name="Hydroanläggningslinje"), Sublayer(name="Hydroanläggningspunkt"), Sublayer(name="Hydrografiskt intressant plats"), Sublayer(name="Hydrolinje"), Sublayer(name="Hydropunkt")]),
    Layer(name="Kommunikation", sublayers=[Sublayer(name="Vägpunkt"), Sublayer(name="Färjeled"), Sublayer(name="Övrig väg"), Sublayer(name="Transportled fjäll"), Sublayer(name="Ledintressepunkt fjäll")]),
    Layer(name="Kulturhistorisk lämning", sublayers=[Sublayer(name="Kulturhistorisk lämning, linje", slug="kultur_lamning_linje"), Sublayer(name="Kulturhistorisk lämning, punkt", slug="kultur_lamning_punkt")]),
    Layer(name="Ledningar", sublayers=[Sublayer(name="Ledningslinje"), Sublayer(name="Transformatorområde"), Sublayer(name="Transformatorområdespunkt")]),
    Layer(name="Mark", sublayers=[Sublayer(name="Mark"), Sublayer(name="Markkantlinje"), Sublayer(name="Sankmark"), Sublayer(name="Markframkomlighet")]),
    Layer(name="Militärt område", sublayers=[Sublayer(name="Militärt område")]),
    Layer(name="Naturvård", sublayers=[Sublayer(name="Naturvårdspunkt"), Sublayer(name="Naturvårdslinje"), Sublayer(name="Restriktionsområde"), Sublayer(name="Skyddad natur", slug="skyddadnatur")]),
    Layer(name="Text", sublayers=[Sublayer(name="Textlinje"), Sublayer(name="textpunkt")]),
]


def to_slug(text: str, space: Literal["", "_"] = "") -> str:
    return text.lower().replace("å", "a").replace("ä", "a").replace("ö", "o").replace(" ", space).replace(",", "")


class FetchBase:
    def __init__(self, layer: str, sublayer: str):
        self.layer = layer
        self.sublayer = sublayer

    def __call__(self, ti: TaskInstance):
        files: list[FileData] = ti.xcom_pull(task_ids="check_ready")
        file = next(f for f in files if f["title"] == f"{self.layer}_sverige.zip")
        df = geopandas.read_file(file["href"], layer=self.sublayer).set_index("objektidentitet")
        return df


with DAG(
        "lm-topografi50-init",
        description="Hämtar Topografi 50 från Lantmäteriet (BAS)",
        schedule_interval=None,
        start_date=datetime(2023, 9, 16, 21, 30),
        catchup=False,
        max_active_runs=1,
        default_args=dict(
            depends_on_past=False,
            email=["jan@dalheimer.de"],
            email_on_failure=True,
            email_on_retry=False,
            retries=1,
            retry_delay=timedelta(minutes=5)
        )
):
    @task()
    def start():
        with lantmateriet() as sess:
            lm_order_start_delivery(sess, Variable.get("LM_TOPO50_ORDER_ID"), "BAS")

    @task.sensor(poke_interval=60)
    def check_ready() -> PokeReturnValue:
        with lantmateriet() as sess:
            res = lm_order_get_delivery(sess, Variable.get("LM_TOPO50_ORDER_ID"))
            if res["status"] == "LYCKAD":
                files = lm_order_get_files(sess, Variable.get("LM_TOPO50_ORDER_ID"))
                return PokeReturnValue(is_done=True, xcom_value=files)
            return PokeReturnValue(is_done=False)

    start_t = start()
    check_ready_t = check_ready()
    start_t >> check_ready_t

    for layer in LAYERS:
        for sublayer in layer["sublayers"]:
            layer_slug = to_slug(layer['name'])
            sublayer_slug = sublayer['slug'] if 'slug' in sublayer else to_slug(sublayer['name'], "_")
            op = FetchDataframeOperator(
                task_id=f"fetch-{layer_slug}-{sublayer_slug}",
                fetch=FetchBase(layer_slug, sublayer_slug),
                provider="Lantmäteriet",
                dataset=f"Topografi 50 ({layer['name']} - {sublayer['name']})",
                dataset_url="https://www.lantmateriet.se/sv/geodata/vara-produkter/produktlista/topografi-50-nedladdning-vektor/",
                license=CC0_1_0,
                outlets=[Dataset(f"psql://upstream/lm/topo50/{layer_slug}/{sublayer_slug}")]
            )
            check_ready_t >> op


with DAG(
        "lm-topografi50-update",
        description="Hämtar Topografi 50 från Lantmäteriet (FÖRÄNDRING)",
        schedule_interval=None,
        start_date=datetime(2023, 9, 16, 21, 30),
        catchup=False,
        max_active_runs=1,
        default_args=dict(
            depends_on_past=False,
            email=["jan@dalheimer.de"],
            email_on_failure=True,
            email_on_retry=False,
            retries=1,
            retry_delay=timedelta(minutes=5)
        )
):
    pass