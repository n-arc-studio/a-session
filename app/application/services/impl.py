from app.config import settings
from app.infrastructure.repositories.postgres import PostgresSongRepository, PostgresTakeRepository, PostgresReviewRepository
from app.infrastructure.storage.minio import MinioStorageGateway, build_take_object_key


class SongServiceImpl:
    """楽曲ユースケースサービス実装"""

    def __init__(self) -> None:
        self._repo = PostgresSongRepository()
        self._storage = MinioStorageGateway()

    def create_song(self, project_id: str, title: str, midi_object_key: str, musicxml_object_key: str | None, bpm: int | None, created_by: str | None) -> dict:
        return self._repo.create(project_id, title, midi_object_key, musicxml_object_key, bpm, created_by)

    def list_songs(
        self,
        project_id: str,
        limit: int | None = None,
        offset: int = 0,
        sort_by: str | None = None,
        sort_order: str = "ASC",
    ) -> list[dict]:
        return self._repo.list_by_project(
            project_id=project_id,
            limit=limit,
            offset=offset,
            sort_by=sort_by,
            sort_order=sort_order,
        )

    def get_midi_download_url(self, song_id: str, expires: int = 900) -> tuple[str, int]:
        object_key = self._repo.get_midi_object_key(song_id)
        if object_key is None:
            raise ValueError("song not found")
        url = self._storage.generate_presigned_download_url(
            bucket=settings.minio_bucket_score,
            object_key=object_key,
            expires=expires,
        )
        return (url, expires)

    def get_score_download_url(self, song_id: str, expires: int = 900) -> tuple[str, int]:
        object_key = self._repo.get_musicxml_object_key(song_id)
        if object_key is None:
            raise ValueError("score not set")
        url = self._storage.generate_presigned_download_url(
            bucket=settings.minio_bucket_score,
            object_key=object_key,
            expires=expires,
        )
        return (url, expires)


class TakeServiceImpl:
    """テイクユースケースサービス実装（Takeアップロードフローをテンプレートとして分離）"""

    def __init__(self) -> None:
        self._repo = PostgresTakeRepository()
        self._storage = MinioStorageGateway()

    def presign_upload(self, song_id: str, user_id: str, filename: str, content_type: str = "audio/webm") -> dict:
        """presigned upload URLを生成するユースケース"""
        object_key = build_take_object_key(song_id, user_id, filename)
        upload_url, _ = self._storage.generate_presigned_upload_url(
            object_key=object_key,
            content_type=content_type,
            expires=900,
        )
        return {
            "object_key": object_key,
            "upload_url": upload_url,
            "expires_in_seconds": 900,
        }

    def create_take(self, song_id: str, user_id: str, audio_object_key: str, duration_ms: int = 0, offset_ms: int = 0, sample_rate: int | None = None) -> dict:
        return self._repo.create(song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate)

    def list_takes(self, song_id: str) -> list[dict]:
        return self._repo.list_by_song(song_id)

    def get_download_url(self, take_id: str, expires: int = 900) -> tuple[str, int]:
        object_key = self._repo.get_audio_object_key(take_id)
        if object_key is None:
            raise ValueError("take not found")
        url = self._storage.generate_presigned_download_url(
            bucket=settings.minio_bucket_audio,
            object_key=object_key,
            expires=expires,
        )
        return (url, expires)


class ReviewServiceImpl:
    """レビューユースケースサービス実装"""

    def __init__(self) -> None:
        self._repo = PostgresReviewRepository()

    def create_review(self, song_id: str, reviewer_id: str, rating: int, comment: str | None) -> dict:
        return self._repo.create(song_id, reviewer_id, rating, comment)

    def list_reviews(self, song_id: str) -> list[dict]:
        return self._repo.list_by_song(song_id)


# Singleton instances for dependency injection
song_service = SongServiceImpl()
take_service = TakeServiceImpl()
review_service = ReviewServiceImpl()
