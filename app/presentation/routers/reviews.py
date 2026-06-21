from fastapi import APIRouter, Query

from app.schemas import CreateReviewRequest, ReviewOut
from app.application.services.impl import review_service


router = APIRouter()


@router.post("/reviews", response_model=ReviewOut)
def create_review(req: CreateReviewRequest) -> ReviewOut:
    result = review_service.create_review(
        song_id=req.song_id,
        reviewer_id=req.reviewer_id,
        rating=req.rating,
        comment=req.comment,
    )
    return ReviewOut(**result)


@router.get("/reviews", response_model=list[ReviewOut])
def list_reviews(song_id: str = Query(...)) -> list[ReviewOut]:
    results = review_service.list_reviews(song_id=song_id)
    return [ReviewOut(**row) for row in results]
