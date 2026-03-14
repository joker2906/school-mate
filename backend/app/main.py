from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "data"
UPLOAD_DIR = BASE_DIR / "uploads"
DB_FILE = DATA_DIR / "store.json"
JWT_SECRET = os.getenv("JWT_SECRET", "schoolmate-dev-secret")
JWT_EXPIRES_SECONDS = int(os.getenv("JWT_EXPIRES_SECONDS", "86400"))

DATA_DIR.mkdir(parents=True, exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


def _load_db() -> Dict[str, Any]:
    if not DB_FILE.exists():
        return {"collections": {}, "auth": {"users": {}, "email_index": {}}}
    with DB_FILE.open("r", encoding="utf-8") as f:
        return json.load(f)


def _save_db(db: Dict[str, Any]) -> None:
    with DB_FILE.open("w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=True, indent=2)


def _normalize_collection(path: str) -> str:
    path = path.strip()
    path = path.strip("/")
    return path


def _collection(db: Dict[str, Any], path: str) -> Dict[str, Dict[str, Any]]:
    name = _normalize_collection(path)
    collections = db.setdefault("collections", {})
    return collections.setdefault(name, {})


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _jwt_encode(payload: Dict[str, Any]) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    header_b64 = _b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    )
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = hmac.new(
        JWT_SECRET.encode("utf-8"), signing_input, hashlib.sha256
    ).digest()
    return f"{header_b64}.{payload_b64}.{_b64url(signature)}"


class AuthRequest(BaseModel):
    email: str
    password: str


class FirestoreFilter(BaseModel):
    field: str
    op: str  # == | in | array_contains | !=
    value: Any


class FirestoreOrder(BaseModel):
    field: str
    descending: bool = False


class FirestoreQueryRequest(BaseModel):
    collection: str
    filters: List[FirestoreFilter] = []
    order_by: List[FirestoreOrder] = []
    limit: Optional[int] = None


class FirestoreSetRequest(BaseModel):
    collection: str
    doc_id: str
    data: Dict[str, Any]
    merge: bool = False


class FirestoreUpdateRequest(BaseModel):
    collection: str
    doc_id: str
    data: Dict[str, Any]


class FirestoreDeleteRequest(BaseModel):
    collection: str
    doc_id: str


class FirestoreGetDocRequest(BaseModel):
    collection: str
    doc_id: str


class FirestoreAddRequest(BaseModel):
    collection: str
    data: Dict[str, Any]


def _apply_field_ops(existing: Dict[str, Any], updates: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(existing)
    for key, value in updates.items():
        if isinstance(value, dict) and value.get("__op") == "arrayUnion":
            current = out.get(key, [])
            if not isinstance(current, list):
                current = []
            for item in value.get("values", []):
                if item not in current:
                    current.append(item)
            out[key] = current
        else:
            out[key] = value
    return out


def _match_filter(doc: Dict[str, Any], f: FirestoreFilter) -> bool:
    val = doc.get(f.field)
    if f.op == "==":
        return val == f.value
    if f.op == "!=":
        return val != f.value
    if f.op == "in":
        if not isinstance(f.value, list):
            return False
        return val in f.value
    if f.op == "array_contains":
        if not isinstance(val, list):
            return False
        return f.value in val
    return False


def _sortable_value(value: Any) -> Any:
    if value is None:
        return (0, "")
    if isinstance(value, (bool, int, float, str)):
        return (1, value)
    if isinstance(value, (dict, list)):
        return (2, json.dumps(value, sort_keys=True, separators=(",", ":")))
    return (3, str(value))


app = FastAPI(title="SchoolMate FastAPI Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/register")
def auth_register(req: AuthRequest) -> Dict[str, Any]:
    db = _load_db()
    auth = db.setdefault("auth", {})
    users = auth.setdefault("users", {})
    email_index = auth.setdefault("email_index", {})

    key = req.email.strip().lower()
    if key in email_index:
        raise HTTPException(status_code=409, detail="email-already-in-use")

    uid = secrets.token_hex(12)
    users[uid] = {
        "uid": uid,
        "email": key,
        "password": req.password,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    email_index[key] = uid
    _save_db(db)
    return {"uid": uid, "email": key}


@app.post("/auth/login")
def auth_login(req: AuthRequest) -> Dict[str, Any]:
    db = _load_db()
    auth = db.get("auth", {})
    users = auth.get("users", {})
    email_index = auth.get("email_index", {})

    key = req.email.strip().lower()
    uid = email_index.get(key)
    if not uid or uid not in users:
        raise HTTPException(status_code=401, detail="invalid-credentials")

    user = users[uid]
    if user.get("password") != req.password:
        raise HTTPException(status_code=401, detail="invalid-credentials")

    role = "unknown"
    profile = {}
    collections = db.get("collections", {})
    for candidate in ["students", "teacher", "parents", "admins"]:
        doc = collections.get(candidate, {}).get(uid)
        if doc is not None:
            role = {
                "students": "student",
                "teacher": "teacher",
                "parents": "parent",
                "admins": "admin",
            }[candidate]
            profile = doc
            break

    now = int(datetime.now(timezone.utc).timestamp())
    token = _jwt_encode(
        {
            "sub": uid,
            "email": key,
            "role": role,
            "iat": now,
            "exp": now + JWT_EXPIRES_SECONDS,
        }
    )

    return {
        "uid": uid,
        "email": key,
        "role": role,
        "profile": profile,
        "access_token": token,
        "token_type": "bearer",
        "expires_in": JWT_EXPIRES_SECONDS,
    }


@app.post("/login")
def login(req: AuthRequest) -> Dict[str, Any]:
    return auth_login(req)


@app.post("/firestore/query")
def firestore_query(req: FirestoreQueryRequest) -> Dict[str, Any]:
    db = _load_db()
    col = _collection(db, req.collection)

    docs = [{"id": doc_id, "data": data} for doc_id, data in col.items()]
    for f in req.filters:
        docs = [d for d in docs if _match_filter(d["data"], f)]

    for order in reversed(req.order_by):
        docs.sort(
            key=lambda d: _sortable_value(d["data"].get(order.field)),
            reverse=order.descending,
        )

    if req.limit is not None:
        docs = docs[: req.limit]

    return {"docs": docs}


@app.post("/firestore/get_doc")
def firestore_get_doc(req: FirestoreGetDocRequest) -> Dict[str, Any]:
    db = _load_db()
    col = _collection(db, req.collection)
    data = col.get(req.doc_id)
    return {"exists": data is not None, "id": req.doc_id, "data": data}


@app.post("/firestore/set_doc")
def firestore_set_doc(req: FirestoreSetRequest) -> Dict[str, Any]:
    db = _load_db()
    col = _collection(db, req.collection)
    if req.merge and req.doc_id in col:
        col[req.doc_id] = _apply_field_ops(col[req.doc_id], req.data)
    else:
        col[req.doc_id] = req.data
    _save_db(db)
    return {"id": req.doc_id}


@app.post("/firestore/update_doc")
def firestore_update_doc(req: FirestoreUpdateRequest) -> Dict[str, Any]:
    db = _load_db()
    col = _collection(db, req.collection)
    if req.doc_id not in col:
        raise HTTPException(status_code=404, detail="doc-not-found")
    col[req.doc_id] = _apply_field_ops(col[req.doc_id], req.data)
    _save_db(db)
    return {"id": req.doc_id}


@app.post("/firestore/delete_doc")
def firestore_delete_doc(req: FirestoreDeleteRequest) -> Dict[str, Any]:
    db = _load_db()
    col = _collection(db, req.collection)
    col.pop(req.doc_id, None)
    _save_db(db)
    return {"ok": True}


@app.post("/firestore/add_doc")
def firestore_add_doc(req: FirestoreAddRequest) -> Dict[str, Any]:
    db = _load_db()
    col = _collection(db, req.collection)
    doc_id = secrets.token_hex(10)
    col[doc_id] = req.data
    _save_db(db)
    return {"id": doc_id}


@app.post("/storage/upload")
async def storage_upload(destination: str, file: UploadFile = File(...)) -> Dict[str, Any]:
    safe_destination = destination.strip().strip("/")
    if not safe_destination:
        safe_destination = f"file_{secrets.token_hex(4)}"

    target = UPLOAD_DIR / safe_destination
    target.parent.mkdir(parents=True, exist_ok=True)

    content = await file.read()
    with target.open("wb") as f:
        f.write(content)

    url = f"/uploads/{safe_destination}"
    return {"url": url, "destination": safe_destination}


@app.get("/storage/url")
def storage_url(destination: str) -> Dict[str, Any]:
    safe_destination = destination.strip().strip("/")
    path = UPLOAD_DIR / safe_destination
    if not path.exists():
        raise HTTPException(status_code=404, detail="file-not-found")
    return {"url": f"/uploads/{safe_destination}"}
