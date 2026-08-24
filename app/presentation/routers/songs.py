from fastapi import APIRouter, HTTPException, Query

from app.schemas import (
    CreateSongRequest,
    DownloadUrlResponse,
    SongOut,
)
from app.application.services.impl import song_service


router = APIRouter()


@router.post("/songs", response_model=SongOut)
def create_song(req: CreateSongRequest) -> SongOut:
    result = song_service.create_song(
        project_id=req.project_id,
        title=req.title,
        midi_object_key=req.midi_object_key,
        musicxml_object_key=req.musicxml_object_key,
        bpm=req.bpm,
        created_by=req.created_by,
    )
    return SongOut(**result)


# 許可される並び替え対象カラムと既定値（SQLインジェクション防止のため白リスト方式）
_ALLOWED_SORT_COLUMNS = {"created_at", "title"}
_DEFAULT_SORT_COLUMN = "created_at"
_DEFAULT_SORT_DIRECTION = "ASC"


@router.get("/songs", response_model=list[SongOut])
def list_songs(
    project_id: str = Query(...),
    limit: int | None = Query(None, ge=1, le=200),
    offset: int = Query(0, ge=0),
    sort_by: str | None = Query(None, min_length=1, max_length=64),
    sort_order: str = Query("ASC", pattern="^(?i)asc|desc$"),
) -> list[SongOut]:
    results = song_service.list_songs(
        project_id=project_id,
        limit=limit,
        offset=offset,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    return [SongOut(**row) for row in results]


@router.get("/songs/{song_id}/midi-download-url", response_model=DownloadUrlResponse)
def get_song_midi_download_url(song_id: str) -> DownloadUrlResponse:
    try:
        url, expires = song_service.get_midi_download_url(song_id=song_id, expires=900)
    except ValueError:
        raise HTTPException(status_code=404, detail="song not found")
    return DownloadUrlResponse(download_url=url, expires_in_seconds=expires)


@router.get("/songs/{song_id}/score-download-url", response_model=DownloadUrlResponse)
def get_song_score_download_url(song_id: str) -> DownloadUrlResponse:
    try:
        url, expires = song_service.get_score_download_url(song_id=song_id, expires=900)
    except ValueError as e:
        if "score not set" in str(e):
            raise HTTPException(status_code=400, detail="score not set")
        raise HTTPException(status_code=404, detail="song not found")
    return DownloadUrlResponse(download_url=url, expires_in_seconds=expires)
