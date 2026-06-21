from datetime import datetime, timezone

import boto3
from botocore.client import Config

from app.config import settings
from app.infrastructure.storage.base import StorageGateway


def _build_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=f"http{'s' if settings.minio_secure else ''}://{settings.minio_endpoint}",
        aws_access_key_id=settings.minio_root_user,
        aws_secret_access_key=settings.minio_root_password,
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",
    )


def build_take_object_key(song_id: str, user_id: str, filename: str) -> str:
    safe_name = filename.replace(" ", "_")
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"takes/{song_id}/{user_id}/{ts}_{safe_name}"


class MinioStorageGateway(StorageGateway):
    """MinIOストレージゲートウェイ実装"""

    def generate_presigned_upload_url(self, object_key: str, content_type: str = "application/octet-stream", expires: int = 900) -> tuple[str, str]:
        s3 = _build_s3_client()
        upload_url = s3.generate_presigned_url(
            ClientMethod="put_object",
            Params={
                "Bucket": settings.minio_bucket_audio,
                "Key": object_key,
                "ContentType": content_type,
            },
            ExpiresIn=expires,
        )
        return (upload_url, object_key)

    def generate_presigned_download_url(self, bucket: str, object_key: str, expires: int = 900) -> str:
        s3 = _build_s3_client()
        url = s3.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": bucket, "Key": object_key},
            ExpiresIn=expires,
        )
        return url
