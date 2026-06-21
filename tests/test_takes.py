"""Integration tests for takes endpoints."""

import uuid


def _create_test_song(client):
    """Helper: create a song and return its ID."""
    response = client.post(
        "/songs",
        json={
            "project_id": "test-project-123",
            "title": "Test Song for Takes",
            "midi_object_key": "midis/test.mid",
            "musicxml_object_key": None,
            "bpm": 120,
            "created_by": "user-456",
        },
    )
    return response.json()["id"]


def test_presign_upload(client):
    """POST /takes/presign-upload should return presigned URL."""
    song_id = _create_test_song(client)
    response = client.post(
        "/takes/presign-upload",
        json={
            "song_id": song_id,
            "user_id": "user-789",
            "filename": "test_audio.webm",
            "content_type": "audio/webm",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert "object_key" in data
    assert "upload_url" in data
    assert "expires_in_seconds" in data


def test_create_take(client):
    """POST /takes should create a take record."""
    song_id = _create_test_song(client)
    response = client.post(
        "/takes",
        json={
            "song_id": song_id,
            "user_id": "user-789",
            "audio_object_key": "takes/test/audio.webm",
            "duration_ms": 15000,
            "offset_ms": 0,
            "sample_rate": 44100,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["song_id"] == song_id
    assert data["user_id"] == "user-789"
    assert "id" in data


def test_list_takes_by_song(client):
    """GET /takes should return takes filtered by song_id."""
    song_id = _create_test_song(client)

    # Create two takes
    for i in range(2):
        client.post(
            "/takes",
            json={
                "song_id": song_id,
                "user_id": f"user-{i}",
                "audio_object_key": f"takes/test/audio{i}.webm",
                "duration_ms": 10000 + i * 5000,
                "offset_ms": 0,
            },
        )

    response = client.get("/takes", params={"song_id": song_id})
    assert response.status_code == 200
    takes = response.json()
    assert len(takes) >= 2


def test_get_take_download_url(client):
    """GET /takes/{take_id}/download-url should return presigned URL."""
    song_id = _create_test_song(client)

    # Create a take first
    create_response = client.post(
        "/takes",
        json={
            "song_id": song_id,
            "user_id": "user-789",
            "audio_object_key": "takes/test/audio.webm",
            "duration_ms": 15000,
            "offset_ms": 0,
        },
    )
    take_id = create_response.json()["id"]

    response = client.get(f"/takes/{take_id}/download-url")
    assert response.status_code == 200
    data = response.json()
    assert "download_url" in data


def test_get_take_download_url_not_found(client):
    """GET /takes/{nonexistent}/download-url should return 404."""
    fake_id = str(uuid.uuid4())
    response = client.get(f"/takes/{fake_id}/download-url")
    assert response.status_code == 404
