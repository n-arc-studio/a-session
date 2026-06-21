"""Integration tests for reviews endpoints."""


def _create_test_song(client):
    """Helper: create a song and return its ID."""
    response = client.post(
        "/songs",
        json={
            "project_id": "test-project-123",
            "title": "Test Song for Reviews",
            "midi_object_key": "midis/test.mid",
            "musicxml_object_key": None,
            "bpm": 120,
            "created_by": "user-456",
        },
    )
    return response.json()["id"]


def test_create_review(client):
    """POST /reviews should create a review and return it."""
    song_id = _create_test_song(client)

    response = client.post(
        "/reviews",
        json={
            "song_id": song_id,
            "reviewer_id": "evaluator-001",
            "rating": 4,
            "comment": "Great performance!",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["song_id"] == song_id
    assert data["reviewer_id"] == "evaluator-001"
    assert data["rating"] == 4
    assert "id" in data


def test_list_reviews_by_song(client):
    """GET /reviews should return reviews filtered by song_id."""
    song_id = _create_test_song(client)

    # Create two reviews
    for i, rating in enumerate([3, 5]):
        client.post(
            "/reviews",
            json={
                "song_id": song_id,
                "reviewer_id": f"evaluator-{i}",
                "rating": rating,
                "comment": f"Review comment {i}",
            },
        )

    response = client.get("/reviews", params={"song_id": song_id})
    assert response.status_code == 200
    reviews = response.json()
    assert len(reviews) >= 2


def test_list_reviews_empty(client):
    """GET /reviews should return empty list when no reviews exist."""
    response = client.get("/reviews", params={"song_id": "nonexistent"})
    assert response.status_code == 200
    assert response.json() == []
