from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import get_connection
from app.schemas import (
    CreateSongRequest,
    CreateTakeRequest,
    DownloadUrlResponse,
    HealthResponse,
    PresignUploadRequest,
    PresignUploadResponse,
    SongOut,
    TakeOut,
)
from app.storage import build_take_object_key, get_s3_client

app = FastAPI(title=settings.app_name)

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok")


@app.post("/songs", response_model=SongOut)
def create_song(req: CreateSongRequest) -> SongOut:
    query = """
        INSERT INTO songs (project_id, title, midi_object_key, musicxml_object_key, bpm, created_by)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id, project_id, title, midi_object_key, musicxml_object_key, bpm
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                query,
                (
                    req.project_id,
                    req.title,
                    req.midi_object_key,
                    req.musicxml_object_key,
                    req.bpm,
                    req.created_by,
                ),
            )
            row = cur.fetchone()
    return SongOut(**row)


@app.get("/songs", response_model=list[SongOut])
def list_songs(project_id: str = Query(...)) -> list[SongOut]:
    query = """
        SELECT id, project_id, title, midi_object_key, musicxml_object_key, bpm
        FROM songs
        WHERE project_id = %s
        ORDER BY created_at ASC
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, (project_id,))
            rows = cur.fetchall()
    return [SongOut(**row) for row in rows]


@app.post("/takes/presign-upload", response_model=PresignUploadResponse)
def presign_take_upload(req: PresignUploadRequest) -> PresignUploadResponse:
    s3 = get_s3_client()
    object_key = build_take_object_key(req.song_id, req.user_id, req.filename)
    expires = 900

    upload_url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": settings.minio_bucket_audio,
            "Key": object_key,
            "ContentType": req.content_type,
        },
        ExpiresIn=expires,
    )

    return PresignUploadResponse(
        object_key=object_key,
        upload_url=upload_url,
        expires_in_seconds=expires,
    )


@app.post("/takes", response_model=TakeOut)
def create_take(req: CreateTakeRequest) -> TakeOut:
    query = """
        INSERT INTO takes (song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate)
        VALUES (%s, %s, %s, %s, %s, %s)
        RETURNING id, song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                query,
                (
                    req.song_id,
                    req.user_id,
                    req.audio_object_key,
                    req.duration_ms,
                    req.offset_ms,
                    req.sample_rate,
                ),
            )
            row = cur.fetchone()
    return TakeOut(**row)


@app.get("/takes", response_model=list[TakeOut])
def list_takes(song_id: str = Query(...)) -> list[TakeOut]:
    query = """
        SELECT id, song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate
        FROM takes
        WHERE song_id = %s
        ORDER BY created_at ASC
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, (song_id,))
            rows = cur.fetchall()
    return [TakeOut(**row) for row in rows]


@app.get("/takes/{take_id}/download-url", response_model=DownloadUrlResponse)
def get_take_download_url(take_id: str) -> DownloadUrlResponse:
    query = "SELECT audio_object_key FROM takes WHERE id = %s"
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, (take_id,))
            row = cur.fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="take not found")

    expires = 900
    s3 = get_s3_client()
    url = s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": settings.minio_bucket_audio, "Key": row["audio_object_key"]},
        ExpiresIn=expires,
    )

    return DownloadUrlResponse(download_url=url, expires_in_seconds=expires)
