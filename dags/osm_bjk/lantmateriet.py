from contextlib import contextmanager
from typing import Generator, Literal, TypedDict

from airflow.hooks.base import BaseHook
from requests import Session

TOKEN_URL = "https://apimanager.lantmateriet.se/oauth2/token"


@contextmanager
def lantmateriet() -> Generator[Session, None, None]:
    with Session() as sess:
        conn = BaseHook.get_connection("LM_OAUTH2")
        token_resp = sess.post("https://apimanager.lantmateriet.se/oauth2/token",
                               auth=(conn.login, conn.password),
                               params=dict(grant_type="client_credentials"))
        token_resp.raise_for_status()
        token = token_resp.json()["access_token"]
        sess.headers["Content-Type"] = "application/json"
        sess.headers["Authorization"] = f"Bearer {token}"
        yield sess


def lm_order_get(sess: Session, order_id: str):
    resp = sess.get(f"https://api.lantmateriet.se/geotorget/orderhanterare/v2/{order_id}")
    resp.raise_for_status()
    return resp.json()


class DeliveryData(TypedDict):
    objektidentitet: str
    skapad: str
    status: Literal["LYCKAD", "PÅGÅENDE"]
    typ: Literal["BAS", "FORANDRING"]


def lm_order_get_delivery(sess: Session, order_id: str) -> DeliveryData:
    resp = sess.get(f"https://api.lantmateriet.se/geotorget/orderhanterare/v2/{order_id}/leverans/latest")
    resp.raise_for_status()
    return resp.json()


def lm_order_start_delivery(sess: Session, order_id: str, type: Literal["BAS", "FORANDRING"]) -> DeliveryData:
    resp = sess.post(f"https://api.lantmateriet.se/geotorget/orderhanterare/v2/{order_id}/leverans?typ={type}")
    resp.raise_for_status()
    return resp.json()


class FileData(TypedDict):
    href: str
    title: str
    type: str
    length: int
    displaySize: str
    updated: str


def lm_order_get_files(sess: Session, order_id: str) -> list[FileData]:
    resp = sess.get(f"https://download-geotorget.lantmateriet.se/download/{order_id}/files")
    resp.raise_for_status()
    return resp.json()
