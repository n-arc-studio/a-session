from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.presentation.routers.songs import router as songs_router
from app.presentation.routers.takes import router as takes_router
from app.presentation.routers.reviews import router as reviews_router


app = FastAPI(title=settings.app_name)

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(songs_router)
app.include_router(takes_router)
app.include_router(reviews_router)
