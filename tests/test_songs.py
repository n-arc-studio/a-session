"""Integration tests for songs endpoints."""

import uuid


def test_create_song(client, sample_song_data):
    """POST /songs should create a song and return it."""
    response = client.post("/songs", json=sample_song_data)
    assert response.status_code == 200
    data = response.json()
    assert data["project_id"] == sample_song_data["project_id"]
    assert data["title"] == sample_song_data["title"]
    assert data["midi_object_key"] == sample_song_data["midi_object_key"]
    assert "id" in data


def test_list_songs_by_project(client, sample_song_data):
    """GET /songs should return songs filtered by project_id."""
    # Create a song first
    client.post("/songs", json=sample_song_data)

    response = client.get(
        "/songs", params={"project_id": sample_song_data["project_id"]}
    )
    assert response.status_code == 200
    songs = response.json()
    assert len(songs) >= 1
    assert songs[0]["title"] == sample_song_data["title"]


def test_list_songs_empty(client):
    """GET /songs should return empty list when no songs exist."""
    response = client.get("/songs", params={"project_id": "nonexistent"})
    assert response.status_code == 200
    assert response.json() == []


def _create_song(client, sample_song_data, title):
    data = dict(sample_song_data)
    data["title"] = title
    return client.post("/songs", json=data)


def test_list_songs_limit(client, sample_song_data):
    """GET /songs?limit=N should return at most N songs."""
    for i in range(5):
        _create_song(client, sample_song_data, f"Song {i}")

    response = client.get("/songs", params={"project_id": sample_song_data["project_id"], "limit": 3})
    assert response.status_code == 200
    songs = response.json()
    assert len(songs) == 3


def test_list_songs_offset(client, sample_song_data):
    """GET /songs?offset=N should skip the first N songs."""
    for i in range(5):
        _create_song(client, sample_song_data, f"Song {i}")

    response = client.get("/songs", params={"project_id": sample_song_data["project_id"], "limit": 2, "offset": 2})
    assert response.status_code == 200
    songs = response.json()
    assert len(songs) == 2


def test_list_songs_sort_by_title(client, sample_song_data):
    """GET /songs?sort_by=title&sort_order=DESC should sort by title descending."""
    _create_song(client, sample_song_data, "Banana")
    _create_song(client, sample_song_data, "Apple")
    _create_song(client, sample_song_data, "Cherry")

    response = client.get(
        "/songs",
        params={"project_id": sample_song_data["project_id"], "sort_by": "title", "sort_order": "DESC"},
    )
    assert response.status_code == 200
    titles = [s["title"] for s in response.json()]
    assert titles == sorted(titles, reverse=True)


def test_list_songs_invalid_sort_column_falls_back(client, sample_song_data):
    """GET /songs with an invalid sort_by should not error (falls back to default)."""
    _create_song(client, sample_song_data, "Song A")

    response = client.get(
        "/songs",
        params={"project_id": sample_song_data["project_id"], "sort_by": "title; DROP TABLE songs"},
    )
    assert response.status_code == 200
    # Table still exists and returns the song
    titles = [s["title"] for s in response.json()]
    assert "Song A" in titles


def test_list_songs_invalid_sort_order_rejected(client, sample_song_data):
    """GET /songs with an invalid sort_order should be rejected by validation."""
    _create_song(client, sample_song_data, "Song A")

    response = client.get(
        "/songs",
        params={"project_id": sample_song_data["project_id"], "sort_order": "DROP TABLE songs"},
    )
    assert response.status_code == 422


def test_list_songs_invalid_limit_rejected(client, sample_song_data):
    """GET /songs with limit below the minimum should be rejected by validation."""
    _create_song(client, sample_song_data, "Song A")

    response = client.get(
        "/songs",
        params={"project_id": sample_song_data["project_id"], "limit": 0},
    )
    assert response.status_code == 422
