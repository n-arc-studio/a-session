from abc import ABC, abstractmethod


class SongRepository(ABC):
    """楽曲リポジトリインターフェース"""

    @abstractmethod
    def create(self, project_id: str, title: str, midi_object_key: str, musicxml_object_key: str | None, bpm: int | None, created_by: str | None) -> dict:
        pass

    @abstractmethod
    def list_by_project(self, project_id: str) -> list[dict]:
        pass

    @abstractmethod
    def get_midi_object_key(self, song_id: str) -> str | None:
        pass

    @abstractmethod
    def get_musicxml_object_key(self, song_id: str) -> str | None:
        pass


class TakeRepository(ABC):
    """テイクリポジトリインターフェース"""

    @abstractmethod
    def create(self, song_id: str, user_id: str, audio_object_key: str, duration_ms: int = 0, offset_ms: int = 0, sample_rate: int | None = None) -> dict:
        pass

    @abstractmethod
    def list_by_song(self, song_id: str) -> list[dict]:
        pass

    @abstractmethod
    def get_audio_object_key(self, take_id: str) -> str | None:
        pass


class ReviewRepository(ABC):
    """レビューリポジトリインターフェース"""

    @abstractmethod
    def create(self, song_id: str, reviewer_id: str, rating: int, comment: str | None) -> dict:
        pass

    @abstractmethod
    def list_by_song(self, song_id: str) -> list[dict]:
        pass
