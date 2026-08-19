from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse
import os

router = APIRouter()

LEGAL_PATH = "/app/legal"

@router.get("/legal/terms")
async def get_terms():
    try:
        with open(f"{LEGAL_PATH}/terms_of_service.txt", "r", encoding="utf-8") as f:
            return PlainTextResponse(f.read())
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Document not found")

@router.get("/legal/privacy")
async def get_privacy():
    try:
        with open(f"{LEGAL_PATH}/privacy_policy.txt", "r", encoding="utf-8") as f:
            return PlainTextResponse(f.read())
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Document not found")

@router.get("/legal/consent")
async def get_consent():
    try:
        with open(f"{LEGAL_PATH}/consent_152_fz.txt", "r", encoding="utf-8") as f:
            return PlainTextResponse(f.read())
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Document not found")

@router.get("/legal/disclaimer")
async def get_disclaimer():
    try:
        with open(f"{LEGAL_PATH}/disclaimer.txt", "r", encoding="utf-8") as f:
            return PlainTextResponse(f.read())
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Document not found")
