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
