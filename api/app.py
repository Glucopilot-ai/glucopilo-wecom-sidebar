import os
import time
import hashlib
import httpx

from fastapi import FastAPI, Query, HTTPException
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

# Load env vars
load_dotenv()
CORP_ID = os.getenv("CORP_ID")
CORP_SECRET = os.getenv("CORP_SECRET")
AGENT_ID = os.getenv("AGENT_ID")

app = FastAPI(title="WeCom Sign API")

# In-memory cache
_cache = {}


# --- Helpers -------------------------------------------------
async def get_access_token() -> str:
    token, exp = _cache.get("access_token", (None, 0))
    if time.time() < exp - 60:
        return token

    url = f"https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid={CORP_ID}&corpsecret={CORP_SECRET}"
    async with httpx.AsyncClient(timeout=10) as cli:
        resp = await cli.get(url)
    data = resp.json()
    if data.get("errcode") != 0:
        raise HTTPException(500, f"gettoken failed: {data}")
    token = data["access_token"]
    _cache["access_token"] = (token, time.time() + data.get("expires_in", 7200))
    return token


async def get_jsapi_ticket() -> str:
    ticket, exp = _cache.get("jsapi_ticket", (None, 0))
    if time.time() < exp - 60:
        return ticket

    token = await get_access_token()
    url = f"https://qyapi.weixin.qq.com/cgi-bin/get_jsapi_ticket?access_token={token}"
    async with httpx.AsyncClient(timeout=10) as cli:
        resp = await cli.get(url)
    data = resp.json()
    if data.get("errcode") != 0:
        raise HTTPException(500, f"jsapi_ticket failed: {data}")
    ticket = data["ticket"]
    _cache["jsapi_ticket"] = (ticket, time.time() + data.get("expires_in", 7200))
    return ticket


async def get_agent_ticket() -> str:
    ticket, exp = _cache.get("agent_ticket", (None, 0))
    if time.time() < exp - 60:
        return ticket

    token = await get_access_token()
    url = f"https://qyapi.weixin.qq.com/cgi-bin/ticket/get?access_token={token}&type=agent_config"
    async with httpx.AsyncClient(timeout=10) as cli:
        resp = await cli.get(url)
    data = resp.json()
    if data.get("errcode") != 0:
        raise HTTPException(500, f"agent_ticket failed: {data}")
    ticket = data["ticket"]
    _cache["agent_ticket"] = (ticket, time.time() + data.get("expires_in", 7200))
    return ticket


def make_signature(ticket: str, nonce: str, ts: int, url: str) -> str:
    raw = f"jsapi_ticket={ticket}&noncestr={nonce}&timestamp={ts}&url={url}"
    return hashlib.sha1(raw.encode()).hexdigest()


# --- Routes --------------------------------------------------

@app.get("/health")
async def health():
    return {"ok": True, "ts": int(time.time())}


@app.get("/wecom/jssdk-sign")
async def jssdk_sign(url: str = Query(..., description="page URL without hash")):
    ticket = await get_jsapi_ticket()
    ts = int(time.time())
    nonce = f"n{ts}"
    sig = make_signature(ticket, nonce, ts, url)
    return JSONResponse({"appId": CORP_ID, "timestamp": ts, "nonceStr": nonce, "signature": sig})


@app.get("/wecom/agent-sign")
async def agent_sign(url: str = Query(..., description="page URL without hash")):
    ticket = await get_agent_ticket()
    ts = int(time.time())
    nonce = f"a{ts}"
    sig = make_signature(ticket, nonce, ts, url)
    return JSONResponse(
        {"corpid": CORP_ID, "agentid": AGENT_ID, "timestamp": ts, "nonceStr": nonce, "signature": sig}
    )



