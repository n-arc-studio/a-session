from abc import ABC, abstractmethod


class SongService(ABC):
    """楽曲ユースケースサービスインターフェース"""

    @abstractmethod
    def create_song(self, project_id: str, title: str, midi_object_key: str, musicxml_object_key: str | None, bpm: int | None, created_by: str | None) -> dict:
        pass

    @abstractmethod
    def list_songs(self, project_id: str) -> list[dict]:
        pass

    @abstractmethod
    def get_midi_download_url(self, song_id: str, expires: int = 900) -> tuple[str, int]:
        pass

    @abstractmethod
    def get_score_download_url(self, song_id: str, expires: int = 900) -> tuple[str, int]:
        pass


class TakeService(ABC):
    """テイクユースケースサービスインターフェース"""

    @abstractmethod
    def presign_upload(self, song_id: str, user_id: str, filename: str, content_type: str = "audio/webm") -> dict:
        pass

    @abstractmethod
    def create_take(self, song_id: str, user_id: str, audio_object_key: str, duration_ms: int = 0, offset_ms: int = 0, sample_rate: int | None = None) -> dict:
        pass

    @abstractmethod
    def list_takes(self, song_id: str) -> list[dict]:
        pass

    @abstractmethod
    def get_download_url(self, take_id: str, expires: int = 900) -> tuple[str, int]:
        pass


class ReviewService(ABC):
    """レビューユースケースサービスインターフェース"""

    @abstractmethod
    def create_review(self, song_id: str, reviewer_id: str, rating: int, comment: str | None) -> dict:
        pass

    @abstractmethod
    def list_reviews(self, song_id: str) -> list[dict]:
        pass
