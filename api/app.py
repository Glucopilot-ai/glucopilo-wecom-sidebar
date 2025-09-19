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


@app.get("/api/diagnostics")
async def diagnostics():
    """Comprehensive diagnostic endpoint for debugging WeCom integration"""
    diagnostics_result = {
        "timestamp": int(time.time()),
        "environment": {
            "CORP_ID_configured": bool(CORP_ID),
            "CORP_SECRET_configured": bool(CORP_SECRET),
            "AGENT_ID_configured": bool(AGENT_ID),
            "CORP_ID_length": len(CORP_ID) if CORP_ID else 0,
            "AGENT_ID_value": AGENT_ID if AGENT_ID else "NOT_SET",
        },
        "cache_status": {
            "access_token_cached": "access_token" in _cache,
            "jsapi_ticket_cached": "jsapi_ticket" in _cache,
            "agent_ticket_cached": "agent_ticket" in _cache,
        },
        "tests": {}
    }

    # Test 1: Try to get access token
    try:
        token = await get_access_token()
        diagnostics_result["tests"]["access_token"] = {
            "success": True,
            "token_length": len(token) if token else 0,
            "token_prefix": token[:10] + "..." if token and len(token) > 10 else token,
        }
    except Exception as e:
        diagnostics_result["tests"]["access_token"] = {
            "success": False,
            "error": str(e),
        }

    # Test 2: Try to get jsapi ticket
    try:
        ticket = await get_jsapi_ticket()
        diagnostics_result["tests"]["jsapi_ticket"] = {
            "success": True,
            "ticket_length": len(ticket) if ticket else 0,
            "ticket_prefix": ticket[:10] + "..." if ticket and len(ticket) > 10 else ticket,
        }
    except Exception as e:
        diagnostics_result["tests"]["jsapi_ticket"] = {
            "success": False,
            "error": str(e),
        }

    # Test 3: Try to get agent ticket
    try:
        ticket = await get_agent_ticket()
        diagnostics_result["tests"]["agent_ticket"] = {
            "success": True,
            "ticket_length": len(ticket) if ticket else 0,
            "ticket_prefix": ticket[:10] + "..." if ticket and len(ticket) > 10 else ticket,
        }
    except Exception as e:
        diagnostics_result["tests"]["agent_ticket"] = {
            "success": False,
            "error": str(e),
        }

    # Test 4: Generate test signatures
    test_url = "https://wecom.jianantech.com"
    try:
        js_ticket = await get_jsapi_ticket()
        ts = int(time.time())
        nonce = f"test{ts}"
        signature = make_signature(js_ticket, nonce, ts, test_url)
        diagnostics_result["tests"]["signature_generation"] = {
            "success": True,
            "test_url": test_url,
            "signature_length": len(signature),
            "signature_sample": signature[:20] + "...",
        }
    except Exception as e:
        diagnostics_result["tests"]["signature_generation"] = {
            "success": False,
            "error": str(e),
        }

    return JSONResponse(diagnostics_result)


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



