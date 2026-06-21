from fastapi import APIRouter, HTTPException, Query

from app.schemas import (
    CreateTakeRequest,
    DownloadUrlResponse,
    PresignUploadRequest,
    PresignUploadResponse,
    TakeOut,
)
from app.application.services.impl import take_service


router = APIRouter()


@router.post("/takes/presign-upload", response_model=PresignUploadResponse)
def presign_take_upload(req: PresignUploadRequest) -> PresignUploadResponse:
    result = take_service.presign_upload(
        song_id=req.song_id,
        user_id=req.user_id,
        filename=req.filename,
        content_type=req.content_type,
    )
    return PresignUploadResponse(**result)


@router.post("/takes", response_model=TakeOut)
def create_take(req: CreateTakeRequest) -> TakeOut:
    result = take_service.create_take(
        song_id=req.song_id,
        user_id=req.user_id,
        audio_object_key=req.audio_object_key,
        duration_ms=req.duration_ms,
        offset_ms=req.offset_ms,
        sample_rate=req.sample_rate,
    )
    return TakeOut(**result)


@router.get("/takes", response_model=list[TakeOut])
def list_takes(song_id: str = Query(...)) -> list[TakeOut]:
    results = take_service.list_takes(song_id=song_id)
    return [TakeOut(**row) for row in results]


@router.get("/takes/{take_id}/download-url", response_model=DownloadUrlResponse)
def get_take_download_url(take_id: str) -> DownloadUrlResponse:
    try:
        url, expires = take_service.get_download_url(take_id=take_id, expires=900)
    except ValueError:
        raise HTTPException(status_code=404, detail="take not found")
    return DownloadUrlResponse(download_url=url, expires_in_seconds=expires)
