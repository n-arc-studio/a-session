"""pytest conftest for A:SESSION backend tests using SQLite."""

import sys
from contextlib import contextmanager
from typing import Generator
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

# Mock psycopg2 and boto3 before importing app modules to avoid missing dependencies
class FakeCursor:
    def __enter__(self):
        return self
    def __exit__(self, *args):
        pass
    def execute(self, *args, **kwargs):
        pass
    def fetchone(self):
        return None
    def fetchall(self):
        return []

class FakeConnection:
    cursor_factory = None
    def cursor(self):
        return FakeCursor()
    def commit(self):
        pass
    def close(self):
        pass

fake_psycopg2 = MagicMock()
fake_psycopg2.connect.return_value = FakeConnection()
sys.modules["psycopg2"] = fake_psycopg2
class FakeExtras:
    RealDictCursor = dict
sys.modules["psycopg2.extras"] = FakeExtras
sys.modules["boto3"] = MagicMock()
sys.modules["botocore"] = MagicMock()
sys.modules["botocore.client"] = MagicMock()


# Global storage for INSERT data (to simulate RETURNING behavior)
_insert_cache = {}  # table_name -> list of inserted rows as dicts

# Create a test db module that will be used during tests
class SQLiteCursorWrapper:
    """Wrap sqlite3.Cursor to support context manager and RETURNING clause."""
    
    def __init__(self, cursor):
        self._cursor = cursor
        self._returning_result = None
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        return False
    
    def execute(self, *args, **kwargs):
        # Convert psycopg2 %s placeholders to SQLite ? placeholders
        if args and isinstance(args[0], str):
            sql = args[0]
            original_sql = sql
            
            # Replace %s with ? for SQLite compatibility
            sql_with_qmarks = sql.replace('%s', '?')
            
            # DEBUG
            import sys
            sql_stripped = sql.strip().upper()
            is_select = sql_stripped.startswith('SELECT')
            is_returning = 'RETURNING' in sql.upper()
            # print(f"[DEBUG] SQL type: SELECT={is_select}, RETURNING={is_returning}, params={len(args)-1}", file=sys.stderr)
            
            # Handle RETURNING clause (PostgreSQL-specific) - case insensitive
            has_returning = 'RETURNING' in sql.upper()
            if has_returning:
                # Find RETURNING position case-insensitively using regex-like approach
                import re
                returning_match = re.search(r'\bRETURNING\b', sql_with_qmarks, re.IGNORECASE)
                insert_sql = sql_with_qmarks[:returning_match.start()].rstrip()
                
                # Parse INSERT INTO table (cols) VALUES (...)
                paren_start = insert_sql.index('(')
                paren_end = insert_sql.index(')', paren_start)
                cols_str = insert_sql[paren_start+1:paren_end]
                cols = [c.strip().split('.')[-1].strip() for c in cols_str.split(',')]
                
                # Get table name (between INTO and first parenthesis)
                into_match = re.search(r'\bINTO\b', insert_sql, re.IGNORECASE)
                table_name = insert_sql[into_match.end():paren_start].strip().split('.')[-1]
                
                # Extract RETURNING columns from original SQL
                returning_cols_str = sql[original_sql.index('RETURNING')+9:].strip()
                returning_cols = [c.strip().split('.')[-1].split(' ')[0].strip() 
                                  for c in returning_cols_str.split(',') if c.strip()]
                
                # Extract params from args - could be tuple or list as second element
                params = []
                if len(args) > 1:
                    param_value = args[1]
                    if isinstance(param_value, (tuple, list)):
                        params = list(param_value)
                    else:
                        params = [param_value]
                
                # Generate id if not in columns, and add it to both cols and params
                if 'id' not in cols:
                    import uuid
                    generated_id = str(uuid.uuid4())
                    cols.insert(0, 'id')
                    params.insert(0, generated_id)
                    
                    # Rebuild the INSERT statement with id column and placeholder
                    cols_part = ', '.join(cols)
                    placeholders = ', '.join(['?' for _ in params])
                    values_part = insert_sql[insert_sql.index('VALUES'):]
                    # Replace VALUES (...) with new placeholders
                    insert_sql = f"INSERT INTO {table_name} ({cols_part}) VALUES ({placeholders})"
                
                # Execute INSERT without RETURNING (now with id)
                self._cursor.execute(insert_sql, tuple(params))
                
                # Build the inserted row dict from columns and params
                # Keep original parameter types - do NOT convert strings to ints
                values_dict = {}
                for i, col in enumerate(cols):
                    if i < len(params):
                        values_dict[col] = params[i]
                
                # Cache the inserted row
                _insert_cache.setdefault(table_name, []).append(values_dict)
                
                # Return the cached result - ensure all RETURNING columns are present
                result = {}
                for col in returning_cols:
                    if col in values_dict:
                        result[col] = values_dict[col]
                    elif col == 'id':
                        last_id = self._cursor.execute("SELECT last_insert_rowid()").fetchone()[0]
                        result[col] = str(last_id)
                    else:
                        result[col] = None
                
                self._returning_result = result
                return
            
            else:
                # Normal query without RETURNING - convert placeholders and execute
                params = []
                if len(args) > 1:
                    param_value = args[1]
                    if isinstance(param_value, (tuple, list)):
                        params = list(param_value)
                    else:
                        params = [param_value]
                return self._cursor.execute(sql_with_qmarks, tuple(params))
            
        return self._cursor.execute(*args, **kwargs)
    
    def executemany(self, *args, **kwargs):
        return self._cursor.executemany(*args, **kwargs)
    
    def executescript(self, *args, **kwargs):
        return self._cursor.executescript(*args, **kwargs)
    
    def fetchone(self, *args, **kwargs):
        # Return cached RETURNING result if available
        if self._returning_result is not None:
            result = self._returning_result
            self._returning_result = None
            return result
        
        result = self._cursor.fetchone(*args, **kwargs)
        # Convert sqlite3.Row to dict
        if result:
            return dict(result) if hasattr(result, 'keys') else result
        return result
    
    def fetchall(self, *args, **kwargs):
        results = self._cursor.fetchall(*args, **kwargs)
        # Convert sqlite3.Row objects to dicts
        converted = []
        for row in results:
            if hasattr(row, 'keys'):
                d = dict(row)
            else:
                d = row
            converted.append(d)
        return converted
    
    def fetchmany(self, *args, **kwargs):
        results = self._cursor.fetchmany(*args, **kwargs)
        # Convert sqlite3.Row objects to dicts
        return [dict(row) if hasattr(row, 'keys') else row for row in results]
    
    @property
    def description(self):
        return self._cursor.description
    
    @property
    def rowcount(self):
        return self._cursor.rowcount
    
    @property
    def lastrowid(self):
        return self._cursor.lastrowid


class SQLiteConnectionWrapper:
    """Wrap sqlite3.Connection to support context manager and cursor() protocol."""
    
    def __init__(self, connection):
        self._conn = connection
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is not None:
            self._conn.rollback()
        else:
            self._conn.commit()
        return False
    
    def cursor(self):
        return SQLiteCursorWrapper(self._conn.cursor())
    
    def execute(self, *args, **kwargs):
        return self._conn.execute(*args, **kwargs)
    
    def executemany(self, *args, **kwargs):
        return self._conn.executemany(*args, **kwargs)
    
    def executescript(self, *args, **kwargs):
        return self._conn.executescript(*args, **kwargs)
    
    def commit(self):
        return self._conn.commit()
    
    def rollback(self):
        return self._conn.rollback()
    
    def close(self):
        return self._conn.close()
    
    @property
    def row_factory(self):
        return self._conn.row_factory
    
    @row_factory.setter
    def row_factory(self, value):
        self._conn.row_factory = value


# Create a test db module that will be used during tests
class TestDB:
    """Test database module that provides SQLite connections."""
    
    @staticmethod
    def get_connection():
        """Return the current SQLite connection from the fixture state."""
        return SQLiteConnectionWrapper(_test_state["conn"])

# Replace app.db BEFORE any test file imports it
sys.modules["app.db"] = TestDB


@pytest.fixture()
def client(tmp_path) -> Generator:
    """Provide a FastAPI TestClient with SQLite-backed database.
    
    Uses file-based SQLite to avoid thread-safety issues with in-memory DBs.
    Each test gets its own isolated database file.
    """
    import sqlite3
    from pathlib import Path

    # Create a temporary file-based SQLite DB with check_same_thread=False for TestClient compatibility
    db_file = tmp_path / "asession_test.db"
    conn = sqlite3.connect(str(db_file), check_same_thread=False)
    conn.row_factory = sqlite3.Row

    init_sql = """
        CREATE TABLE songs (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            title TEXT NOT NULL,
            midi_object_key TEXT NOT NULL,
            musicxml_object_key TEXT,
            bpm INTEGER,
            created_by TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE takes (
            id TEXT PRIMARY KEY,
            song_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            audio_object_key TEXT NOT NULL,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            offset_ms INTEGER NOT NULL DEFAULT 0,
            sample_rate INTEGER,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE reviews (
            id TEXT PRIMARY KEY,
            song_id TEXT NOT NULL,
            reviewer_id TEXT NOT NULL,
            rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
            comment TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX idx_songs_project_id ON songs(project_id);
        CREATE INDEX idx_takes_song_id ON takes(song_id);
        CREATE INDEX idx_reviews_song_id ON reviews(song_id);
    """
    conn.executescript(init_sql)

    # Store connection in module-level state so TestDB.get_connection can access it
    _test_state["conn"] = conn

    import app.main  # noqa: F811, E402
    from fastapi.testclient import TestClient  # noqa: F811, E402
    
    # Patch app.main.get_connection to use our test DB
    def test_get_connection():
        return SQLiteConnectionWrapper(_test_state["conn"])
    
    app.main.get_connection = test_get_connection
    
    # Mock S3 client
    def mock_get_s3_client():
        mock_s3 = MagicMock()
        mock_s3.generate_presigned_url.return_value = "https://example.com/test.mp3"
        return mock_s3
    
    # Patch both app.main and app.storage
    app.main.get_s3_client = mock_get_s3_client
    import app.storage
    app.storage.get_s3_client = mock_get_s3_client

    client = TestClient(app.main.app)
    yield client
    
    # Cleanup
    conn.close()
    _test_state["conn"] = None


# Module-level state to hold the current test connection
_test_state = {"conn": None}


@pytest.fixture()
def sample_song_data():
    """Provide sample song creation data."""
    return {
        "project_id": "test-project-123",
        "title": "Test Song",
        "midi_object_key": "midis/test.mid",
        "musicxml_object_key": "scores/test.xml",
        "bpm": 120,
        "created_by": "user-456",
    }


@pytest.fixture()
def sample_take_data():
    """Provide sample take creation data."""
    return {
        "song_id": "test-song-id",
        "user_id": "user-789",
        "audio_object_key": "takes/test/audio.webm",
        "duration_ms": 15000,
        "offset_ms": 0,
        "sample_rate": 44100,
    }


@pytest.fixture()
def sample_review_data():
    """Provide sample review creation data."""
    return {
        "song_id": "test-song-id",
        "reviewer_id": "evaluator-001",
        "rating": 4,
        "comment": "Great performance!",
    }
