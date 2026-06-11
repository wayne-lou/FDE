r"""
HoloMemory Voice Bridge - FastAPI / Python 3.13 compatible

Run with the existing venv313:
  cd C:\inetpub\demos\demo_hm\voice_clone_service
  venv313\Scripts\activate
  set HM_VOICE_PROVIDER=minimax
  set MINIMAX_REGION=cn
  set MINIMAX_API_HOST=https://api.minimax.chat
  set MINIMAX_API_KEY=YOUR_KEY
  set HM_PUBLIC_BASE_URL=http://demos.e-xanke.com/demo_hm
  uvicorn server:app --host 0.0.0.0 --port 8010
"""
from __future__ import annotations

import base64
import binascii
import json
import mimetypes
import os
import time
import uuid
from pathlib import Path
from typing import Any, Dict, Optional

import requests
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="HoloMemory Voice Bridge", version="v30")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PROJECT_ROOT = Path(os.environ.get("HM_PROJECT_ROOT", r"C:\inetpub\demos\demo_hm")).resolve()
OUTPUT_DIR = PROJECT_ROOT / "uploads" / "generated_voice"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MINIMAX_API_DEFAULT = "https://api.minimax.chat"
ELEVEN_API = "https://api.elevenlabs.io"
DID_API = "https://api.d-id.com"


class VoiceRequest(BaseModel):
    text: str = ""
    speaker_wav: str = ""
    language: str = "zh-cn"
    persona_id: Any = "default"
    persona_name: str = "HoloMemory Persona"
    provider: str = "minimax"
    provider_voice_id: str = ""
    action: str = "tts"
    minimax_api_key: str = ""
    minimax_region: str = ""
    minimax_api_host: str = ""
    minimax_group_id: str = ""
    hm_public_base_url: str = ""


class AvatarRequest(BaseModel):
    image_url: str = ""
    audio_url: str = ""
    persona_name: str = "HoloMemory Persona"
    provider: str = "did"


def minimax_api_host(req: Optional[VoiceRequest] = None) -> str:
    host = ((req.minimax_api_host if req else "") or os.environ.get("MINIMAX_API_HOST", "")).strip().rstrip("/")
    if host:
        return host
    region = ((req.minimax_region if req else "") or os.environ.get("MINIMAX_REGION", "cn")).strip().lower()
    if region in ("cn", "china", "mainland", "domestic"):
        return "https://api.minimax.chat"
    if region in ("global", "intl", "international"):
        return "https://api.minimax.io"
    return MINIMAX_API_DEFAULT


def minimax_url(path: str, req: Optional[VoiceRequest] = None) -> str:
    url = minimax_api_host(req) + path
    group_id = ((req.minimax_group_id if req else "") or os.environ.get("MINIMAX_GROUP_ID", "")).strip()
    if group_id:
        sep = "&" if "?" in url else "?"
        url = f"{url}{sep}GroupId={group_id}"
    return url


def public_url(relative_or_abs: str, req: Optional[VoiceRequest] = None) -> str:
    if not relative_or_abs:
        return ""
    if relative_or_abs.startswith("http://") or relative_or_abs.startswith("https://"):
        return relative_or_abs
    base = ((req.hm_public_base_url if req else "") or os.environ.get("HM_PUBLIC_BASE_URL", "")).strip().rstrip("/")
    if not base:
        return ""
    return base + "/" + relative_or_abs.replace("\\", "/").lstrip("/")


def save_bytes(data: bytes, suffix: str = ".mp3") -> Dict[str, str]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    name = f"hm_voice_{int(time.time())}_{uuid.uuid4().hex[:8]}{suffix}"
    path = OUTPUT_DIR / name
    path.write_bytes(data)
    rel = f"uploads/generated_voice/{name}"
    return {"path": str(path), "relative_url": rel, "public_url": public_url(rel)}


def safe_json_response(resp: requests.Response) -> Dict[str, Any]:
    text = resp.text or ""
    try:
        return resp.json()
    except Exception:
        raise RuntimeError(f"Provider returned non-JSON HTTP {resp.status_code}: {text[:1000]}")




def require_ascii_header_value(name: str, value: str) -> str:
    try:
        value.encode("latin-1")
    except UnicodeEncodeError:
        raise RuntimeError(
            f"{name} contains non-ASCII characters. Re-set it in CMD with the real ASCII API key, "
            f"not Chinese placeholder text. Example: set {name}=sk-..."
        )
    return value

def minimax_headers(api_key: str) -> Dict[str, str]:
    token = require_ascii_header_value("MINIMAX_API_KEY", f"Bearer {api_key}")
    return {"Authorization": token}


def ascii_upload_filename(path: Path) -> str:
    ext = path.suffix.lower()
    if ext not in (".mp3", ".wav", ".m4a", ".mpeg", ".mp4"):
        ext = ".mp3"
    return "voice_sample" + ext


def minimax_upload_file(api_key: str, file_path: str, req: Optional[VoiceRequest] = None) -> str:
    path = Path(file_path)
    if not path.exists():
        raise RuntimeError(f"speaker sample file not found: {file_path}")
    url = minimax_url("/v1/files/upload", req)
    content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    safe_name = ascii_upload_filename(path)
    with path.open("rb") as f:
        # IMPORTANT: requests/multipart headers are latin-1 encoded. Never pass user-uploaded
        # filenames here, because Chinese filenames cause: latin-1 codec can't encode characters.
        files = {"file": (safe_name, f, content_type)}
        data = {"purpose": "voice_clone"}
        resp = requests.post(url, headers=minimax_headers(api_key), data=data, files=files, timeout=180)
    if resp.status_code < 200 or resp.status_code >= 300:
        raise RuntimeError(f"MiniMax upload HTTP {resp.status_code}: {resp.text[:1000]}")
    payload = safe_json_response(resp)
    file_id = (payload.get("file") or {}).get("file_id") or payload.get("file_id") or payload.get("id")
    if not file_id:
        raise RuntimeError("MiniMax upload response did not include file_id: " + json.dumps(payload, ensure_ascii=False)[:1000])
    return str(file_id)


def minimax_base_ok(payload: Dict[str, Any]) -> bool:
    base = payload.get("base_resp") or payload.get("base_response") or {}
    code = base.get("status_code", 0)
    try:
        return int(code) == 0
    except Exception:
        return str(code) in ("0", "", "None")


def minimax_base_message(payload: Dict[str, Any]) -> str:
    base = payload.get("base_resp") or payload.get("base_response") or {}
    return str(base.get("status_msg") or base.get("message") or payload.get("error") or "")


def minimax_clone(api_key: str, source_file_id: str, voice_id: str, preview_text: str, req: Optional[VoiceRequest] = None) -> Dict[str, Any]:
    url = minimax_url("/v1/voice_clone", req)
    payload = {
        "file_id": int(source_file_id) if str(source_file_id).isdigit() else source_file_id,
        "voice_id": voice_id,
        "text": (preview_text or "你好，我是你的记忆陪伴者。")[:900],
        "model": os.environ.get("MINIMAX_CLONE_MODEL", "speech-2.8-hd"),
        "need_noise_reduction": True,
        "need_volume_normalization": True,
    }
    resp = requests.post(url, headers={**minimax_headers(api_key), "Content-Type": "application/json"}, json=payload, timeout=180)
    if resp.status_code < 200 or resp.status_code >= 300:
        raise RuntimeError(f"MiniMax voice_clone HTTP {resp.status_code}: {resp.text[:1200]}")
    res = safe_json_response(resp)
    if not minimax_base_ok(res):
        raise RuntimeError("MiniMax voice_clone failed: " + json.dumps(res, ensure_ascii=False)[:1200])
    return res


def minimax_t2a(api_key: str, voice_id: str, text: str, req: Optional[VoiceRequest] = None) -> Dict[str, Any]:
    url = minimax_url("/v1/t2a_v2", req)
    payload = {
        "model": os.environ.get("MINIMAX_TTS_MODEL", "speech-2.8-hd"),
        "text": text,
        "stream": False,
        "language_boost": "Chinese",
        "output_format": "hex",
        "voice_setting": {"voice_id": voice_id, "speed": 1, "vol": 1, "pitch": 0},
        "audio_setting": {"sample_rate": 32000, "bitrate": 128000, "format": "mp3", "channel": 1},
    }
    resp = requests.post(url, headers={**minimax_headers(api_key), "Content-Type": "application/json"}, json=payload, timeout=180)
    if resp.status_code < 200 or resp.status_code >= 300:
        raise RuntimeError(f"MiniMax t2a_v2 HTTP {resp.status_code}: {resp.text[:1200]}")
    res = safe_json_response(resp)
    audio_hex = ((res.get("data") or {}).get("audio") or "").strip()
    if not audio_hex:
        raise RuntimeError("MiniMax T2A response did not include data.audio: " + json.dumps(res, ensure_ascii=False)[:1200])
    try:
        audio_bytes = binascii.unhexlify(audio_hex)
    except Exception:
        audio_bytes = base64.b64decode(audio_hex)
    saved = save_bytes(audio_bytes, ".mp3")
    return {"saved": saved, "raw": res}


def minimax_generate(req: VoiceRequest) -> Dict[str, Any]:
    api_key = (req.minimax_api_key or os.environ.get("MINIMAX_API_KEY", "")).strip()
    if not api_key:
        raise RuntimeError("MiniMax API key is not configured. Set application.minimaxApiKey in Application.cfc or MINIMAX_API_KEY in the uvicorn process.")
    require_ascii_header_value("MINIMAX_API_KEY", f"Bearer {api_key}")
    text = req.text.strip()
    if not text:
        raise RuntimeError("text is required")

    action = (req.action or "tts").strip().lower()
    force_prepare = action in ("prepare_clone", "clone", "prepare")
    voice_id = (req.provider_voice_id or "").strip()

    # Prepare clone must create/update the provider voice profile only.
    # Do NOT immediately call T2A here; MiniMax may not make the new voice_id
    # available to T2A instantly, and that caused the confusing 2054
    # "voice id not exist" error even when the clone call itself was the step being tested.
    if force_prepare:
        if not req.speaker_wav or not Path(req.speaker_wav).exists():
            raise RuntimeError("MiniMax prepare_clone requires a valid uploaded speaker sample path")
        file_id = minimax_upload_file(api_key, req.speaker_wav, req)
        safe_persona = ''.join(ch for ch in str(req.persona_id or "default") if ch.isalnum()) or "default"
        new_voice_id = "hm" + safe_persona + "_" + uuid.uuid4().hex[:12]
        clone_res = minimax_clone(api_key, file_id, new_voice_id, text[:200] or "今天天气很好，我们慢慢聊。", req)
        return {
            "success": True,
            "provider": "minimax",
            "engine": "minimax_voice_clone_profile",
            "provider_voice_id": new_voice_id,
            "audio_url": "",
            "audio_public_url": "",
            "cloned_now": True,
            "clone_response": clone_res,
            "message": "MiniMax voice clone profile created. Use this provider_voice_id for later TTS.",
        }

    cloned_now = False
    if not voice_id:
        if not req.speaker_wav or not Path(req.speaker_wav).exists():
            raise RuntimeError("MiniMax TTS requires provider_voice_id or a valid uploaded speaker sample path")
        file_id = minimax_upload_file(api_key, req.speaker_wav, req)
        safe_persona = ''.join(ch for ch in str(req.persona_id or "default") if ch.isalnum()) or "default"
        voice_id = "hm" + safe_persona + "_" + uuid.uuid4().hex[:12]
        minimax_clone(api_key, file_id, voice_id, text[:200] or "今天天气很好，我们慢慢聊。", req)
        cloned_now = True

    tts = minimax_t2a(api_key, voice_id, text, req)
    return {
        "success": True,
        "provider": "minimax",
        "engine": "minimax_voice_clone_t2a",
        "provider_voice_id": voice_id,
        "audio_url": tts["saved"]["relative_url"],
        "audio_public_url": tts["saved"].get("public_url", ""),
        "cloned_now": cloned_now,
        "message": "MiniMax cloned voice TTS generated audio successfully.",
    }


def elevenlabs_generate(req: VoiceRequest) -> Dict[str, Any]:
    raise RuntimeError("ElevenLabs adapter is not enabled in this v18 server. Use MiniMax first.")


def did_create_talk(req: AvatarRequest) -> Dict[str, Any]:
    api_key = os.environ.get("D_ID_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("D_ID_API_KEY is not configured")
    source_url = public_url(req.image_url)
    audio_url = public_url(req.audio_url)
    if not source_url or not audio_url:
        raise RuntimeError("D-ID requires public image_url and audio_url. Set HM_PUBLIC_BASE_URL.")
    payload = {
        "source_url": source_url,
        "script": {"type": "audio", "audio_url": audio_url},
        "config": {"stitch": True, "fluent": True, "pad_audio": 0.2},
        "name": req.persona_name or "HoloMemory Talking Head",
    }
    resp = requests.post(f"{DID_API}/talks", headers={"Authorization": "Basic " + api_key, "Content-Type": "application/json"}, json=payload, timeout=120)
    if resp.status_code < 200 or resp.status_code >= 300:
        raise RuntimeError(f"D-ID HTTP {resp.status_code}: {resp.text[:1000]}")
    res = safe_json_response(resp)
    return {"success": True, "provider": "did", "talk_id": res.get("id"), "status": res.get("status"), "result_url": res.get("result_url", ""), "raw": res}


@app.get("/health")
def health():
    return {
        "success": True,
        "service": "HoloMemory FastAPI voice bridge",
        "version": "v30",
        "provider": os.environ.get("HM_VOICE_PROVIDER", "minimax"),
        "minimax_configured": bool(os.environ.get("MINIMAX_API_KEY", "").strip()),
        "minimax_key_prefix": (os.environ.get("MINIMAX_API_KEY", "").strip()[:6] + "...") if os.environ.get("MINIMAX_API_KEY", "").strip() else "",
        "minimax_api_host": minimax_api_host(),
        "minimax_group_id_configured": bool(os.environ.get("MINIMAX_GROUP_ID", "").strip()),
        "public_base_url": os.environ.get("HM_PUBLIC_BASE_URL", ""),
        "project_root": str(PROJECT_ROOT),
    }


@app.post("/tts")
def tts(req: VoiceRequest):
    try:
        provider = (req.provider or os.environ.get("HM_VOICE_PROVIDER") or "minimax").strip().lower()
        if provider in ("minimax", "minimax_cn", "minimax_china"):
            return minimax_generate(req)
        if provider == "elevenlabs":
            return elevenlabs_generate(req)
        return {"success": False, "provider": provider, "error": "unsupported voice provider"}
    except Exception as e:
        return {"success": False, "provider": req.provider or "minimax", "error": str(e), "message": "Provider bridge failed. Check API key, sample path, audio duration, and MiniMax account balance."}


@app.post("/avatar")
def avatar(req: AvatarRequest):
    try:
        provider = (req.provider or os.environ.get("HM_AVATAR_PROVIDER") or "did").strip().lower()
        if provider == "did":
            return did_create_talk(req)
        return {"success": False, "provider": provider, "error": "unsupported avatar provider"}
    except Exception as e:
        return {"success": False, "provider": req.provider or "did", "error": str(e)}
