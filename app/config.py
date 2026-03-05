from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "A:SESSION API"
    app_env: str = "dev"
    app_port: int = 8000

    postgres_host: str = "postgres"
    postgres_port: int = 5432
    postgres_db: str = "asession"
    postgres_user: str = "asession"
    postgres_password: str = "asession"

    minio_endpoint: str = "minio:9000"
    minio_root_user: str = "minioadmin"
    minio_root_password: str = "minioadmin"
    minio_secure: bool = False
    minio_bucket_audio: str = "a-session-audio"
    minio_bucket_score: str = "a-session-score"

    cors_origins: str = "*"


settings = Settings()
