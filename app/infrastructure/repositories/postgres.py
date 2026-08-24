import uuid
from typing import Literal

from app.db import get_connection
from app.infrastructure.repositories.base import SongRepository, TakeRepository, ReviewRepository

# 並び替え方向の型定義（FastAPIのpatternと整合）
SortOrder = Literal["ASC", "DESC"]

# 許可される並び替え対象カラム（SQLインジェクション防止のため白リスト方式）
_ALLOWED_SORT_COLUMNS = {"created_at", "title"}
_DEFAULT_SORT_COLUMN = "created_at"


class PostgresSongRepository(SongRepository):
    """楽曲リポジトリ（PostgreSQL実装）"""

    def create(self, project_id: str, title: str, midi_object_key: str, musicxml_object_key: str | None, bpm: int | None, created_by: str | None) -> dict:
        song_id = str(uuid.uuid4())
        query = """
            INSERT INTO songs (id, project_id, title, midi_object_key, musicxml_object_key, bpm, created_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (song_id, project_id, title, midi_object_key, musicxml_object_key, bpm, created_by))
        return {
            "id": song_id,
            "project_id": project_id,
            "title": title,
            "midi_object_key": midi_object_key,
            "musicxml_object_key": musicxml_object_key,
            "bpm": bpm,
        }

    def list_by_project(
        self,
        project_id: str,
        limit: int | None = None,
        offset: int = 0,
        sort_by: str | None = None,
        sort_order: SortOrder = "ASC",
    ) -> list[dict]:
        # 並び替えカラムは白リストで正規化（インジェクション防止）
        column = (sort_by or _DEFAULT_SORT_COLUMN).lower()
        if column not in _ALLOWED_SORT_COLUMNS:
            column = _DEFAULT_SORT_COLUMN

        query = f"""
            SELECT id, project_id, title, midi_object_key, musicxml_object_key, bpm
            FROM songs
            WHERE project_id = %s
            ORDER BY {column} {sort_order}
        """
        params: list[object] = [project_id]

        # ページング（limit=None は全件取得＝既存クライアントとの後方互換）
        if limit is not None:
            query += " LIMIT %s"
            params.append(limit)
        if offset and offset > 0:
            query += " OFFSET %s"
            params.append(offset)

        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, tuple(params))
                return cur.fetchall()

    def get_midi_object_key(self, song_id: str) -> str | None:
        query = "SELECT midi_object_key FROM songs WHERE id = %s"
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (song_id,))
                row = cur.fetchone()
        return row["midi_object_key"] if row else None

    def get_musicxml_object_key(self, song_id: str) -> str | None:
        query = "SELECT musicxml_object_key FROM songs WHERE id = %s"
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (song_id,))
                row = cur.fetchone()
        return row["musicxml_object_key"] if row else None


class PostgresTakeRepository(TakeRepository):
    """テイクリポジトリ（PostgreSQL実装）"""

    def create(self, song_id: str, user_id: str, audio_object_key: str, duration_ms: int = 0, offset_ms: int = 0, sample_rate: int | None = None) -> dict:
        take_id = str(uuid.uuid4())
        query = """
            INSERT INTO takes (id, song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (take_id, song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate))
        return {
            "id": take_id,
            "song_id": song_id,
            "user_id": user_id,
            "audio_object_key": audio_object_key,
            "duration_ms": duration_ms,
            "offset_ms": offset_ms,
            "sample_rate": sample_rate,
        }

    def list_by_song(self, song_id: str) -> list[dict]:
        query = """
            SELECT id, song_id, user_id, audio_object_key, duration_ms, offset_ms, sample_rate
            FROM takes
            WHERE song_id = %s
            ORDER BY created_at ASC
        """
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (song_id,))
                return cur.fetchall()

    def get_audio_object_key(self, take_id: str) -> str | None:
        query = "SELECT audio_object_key FROM takes WHERE id = %s"
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (take_id,))
                row = cur.fetchone()
        return row["audio_object_key"] if row else None


class PostgresReviewRepository(ReviewRepository):
    """レビューリポジトリ（PostgreSQL実装）"""

    def create(self, song_id: str, reviewer_id: str, rating: int, comment: str | None) -> dict:
        review_id = str(uuid.uuid4())
        query = """
            INSERT INTO reviews (id, song_id, reviewer_id, rating, comment)
            VALUES (%s, %s, %s, %s, %s)
        """
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (review_id, song_id, reviewer_id, rating, comment))
        return {
            "id": review_id,
            "song_id": song_id,
            "reviewer_id": reviewer_id,
            "rating": rating,
            "comment": comment,
        }

    def list_by_song(self, song_id: str) -> list[dict]:
        query = """
            SELECT id, song_id, reviewer_id, rating, comment
            FROM reviews
            WHERE song_id = %s
            ORDER BY created_at DESC
        """
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(query, (song_id,))
                return cur.fetchall()
