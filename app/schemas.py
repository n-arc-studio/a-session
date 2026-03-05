from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str


class CreateSongRequest(BaseModel):
    project_id: str
    title: str = Field(min_length=1)
    midi_object_key: str = Field(min_length=1)
    musicxml_object_key: str | None = None
    bpm: int | None = None
    created_by: str | None = None


class SongOut(BaseModel):
    id: str
    project_id: str
    title: str
    midi_object_key: str
    musicxml_object_key: str | None
    bpm: int | None


class PresignUploadRequest(BaseModel):
    song_id: str
    user_id: str
    filename: str
    content_type: str = "audio/webm"


class PresignUploadResponse(BaseModel):
    object_key: str
    upload_url: str
    expires_in_seconds: int


class CreateTakeRequest(BaseModel):
    song_id: str
    user_id: str
    audio_object_key: str
    duration_ms: int = 0
    offset_ms: int = 0
    sample_rate: int | None = None


class TakeOut(BaseModel):
    id: str
    song_id: str
    user_id: str
    audio_object_key: str
    duration_ms: int
    offset_ms: int
    sample_rate: int | None


class DownloadUrlResponse(BaseModel):
    download_url: str
    expires_in_seconds: int


class CreateReviewRequest(BaseModel):
    song_id: str
    reviewer_id: str
    rating: int = Field(ge=1, le=5)
    comment: str | None = None


class ReviewOut(BaseModel):
    id: str
    song_id: str
    reviewer_id: str
    rating: int
    comment: str | None
