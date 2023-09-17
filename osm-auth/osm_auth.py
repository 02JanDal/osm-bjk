import os
from datetime import datetime, timedelta, timezone
from secrets import token_hex
from typing import Optional, Literal
from urllib.parse import quote_plus

from aiohttp import ClientSession
from fastapi import FastAPI, Response, Cookie, Header, Query
from pydantic import BaseModel

import jwt
from starlette.responses import RedirectResponse

app = FastAPI()


AUTH_URL = "https://www.openstreetmap.org/oauth2/authorize"
TOKEN_URL = "https://www.openstreetmap.org/oauth2/token"
SCOPES = ["read_prefs", "write_api", "write_notes"]
BASE = os.environ.get("BASE", "https://osm.jandal.se")
CLIENT_ID = os.environ.get("CLIENT_ID")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET")
SECRET = os.environ.get("SECRET")
ADMIN_USERS = [int(v.strip()) for v in os.environ.get("ADMIN_USERS", "").split(",")]
ADMIN_ONLY_PATHS = os.environ.get("ADMIN_ONLY_PATHS", "").split(",")


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: Literal["Bearer"]
    scope: str
    created_at: int


class UserResponseUser(BaseModel):
    id: int
    display_name: str
    account_created: str
    description: str
    contributor_terms: dict
    img: dict
    roles: list
    changesets: dict
    traces: dict
    blocks: dict
    home: dict
    languages: list[str]
    messages: dict


class UserResponse(BaseModel):
    version: Literal["0.6"]
    generator: Literal["OpenStreetMap server"]
    user: UserResponseUser


class TokenContent(BaseModel):
    access_token: str
    user_id: int
    user_name: str


@app.get("/auth/callback")
async def callback(code: str, state: str, osm_temporary: str | None = Cookie(default=None)):

    osm_temporary = jwt.decode(
        osm_temporary,
        SECRET,
        issuer="osm.jandal.se",
        audience="osm.jandal.se",
        algorithms=["HS256"]
    )
    redirect = osm_temporary["redirect"]
    response = RedirectResponse(BASE + (redirect if redirect and redirect.startswith("/") else "/"))

    if osm_temporary["state"] != state:
        response.status_code = 400
        return response

    async with ClientSession() as session:
        async with session.post(TOKEN_URL, data=dict(
            code=code,
            grant_type="authorization_code",
            redirect_uri=BASE + "/auth/callback",
            client_id=CLIENT_ID,
            client_secret=CLIENT_SECRET
        )) as resp:
            if not resp.ok:
                response.status_code = 400
                return response
            raw = await resp.json()
            token_response = AccessTokenResponse(**raw)
        async with session.get("https://api.openstreetmap.org/api/0.6/user/details.json", headers=dict(Authorization="Bearer " + token_response.access_token)) as resp:
            if not resp.ok:
                response.status_code = 400
                return response
            raw = await resp.json()
            user_response = UserResponse(**raw)
        token = TokenContent(
            access_token=token_response.access_token,
            user_id=user_response.user.id,
            user_name=user_response.user.display_name
        )
        token_encoded = jwt.encode(dict(
            **token.model_dump(mode="json"),
            nbf=token_response.created_at,
            iat=token_response.created_at,
            iss="openstreetmap.org"
        ), SECRET, algorithm="HS256")
        response.set_cookie("osm_session", token_encoded,
                            httponly=True, secure=True, domain="osm.jandal.se", samesite="lax")

    return response


@app.get("/auth/start")
def start(redirect: str | None = Query(default=None)):
    redirect = quote_plus(redirect.replace("https://osm.jandal.se", "")) if redirect else ""
    state = token_hex(16)
    response = RedirectResponse(
        f"{AUTH_URL}?response_type=code&client_id={CLIENT_ID}&redirect_uri={BASE}/auth/callback&scope={'+'.join(SCOPES)}&state={state}"
    )
    now = datetime.now(tz=timezone.utc)
    expiry = now + timedelta(minutes=3)
    response.set_cookie("osm_temporary", jwt.encode(dict(
        redirect=redirect,
        state=state,
        nbf=now,
        iat=now,
        exp=expiry,
        iss="osm.jandal.se",
        aud="osm.jandal.se"
    ), SECRET, algorithm="HS256"),
                        httponly=True, secure=True, domain="osm.jandal.se", samesite="strict", expires=expiry)
    return response


@app.get("/auth")
def auth(
        response: Response,
        osm_session: str | None = Cookie(default=None),
        x_original_url: str = Header()
):
    if osm_session:
        token = TokenContent(**jwt.decode(osm_session, SECRET, issuer="openstreetmap.org", algorithms=["HS256"]))
        if token:
            response.headers["X-User-ID"] = str(token.user_id)
            response.headers["X-User-Name"] = token.user_name
            if token.user_id in ADMIN_USERS:
                response.headers["X-User-Group"] = "admin"
            elif any(x_original_url.startswith(path) for path in ADMIN_ONLY_PATHS):
                response.status_code = 403
                return "User must be admin"
            return "User authenticated"
    response.status_code = 401
    return "User not authenticated"
