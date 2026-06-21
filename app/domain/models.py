from pydantic import BaseModel, Field


class Song(BaseModel):
    """楽曲エンティティ（ドメインモデル）"""
    id: str
    project_id: str
    title: str
    midi_object_key: str
    musicxml_object_key: str | None = None
    bpm: int | None = None


class Take(BaseModel):
    """テイクエンティティ（ドメインモデル）"""
    id: str
    song_id: str
    user_id: str
    audio_object_key: str
    duration_ms: int
    offset_ms: int
    sample_rate: int | None = None


class Review(BaseModel):
    """レビューエンティティ（ドメインモデル）"""
    id: str
    song_id: str
    reviewer_id: str
    rating: int
    comment: str | None = None
