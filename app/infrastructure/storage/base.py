from abc import ABC, abstractmethod


class StorageGateway(ABC):
    """ストレージゲートウェイインターフェース（MinIO/S3）"""

    @abstractmethod
    def generate_presigned_upload_url(self, object_key: str, content_type: str = "application/octet-stream", expires: int = 900) -> tuple[str, str]:
        """
        Returns (upload_url, object_key)
        """
        pass

    @abstractmethod
    def generate_presigned_download_url(self, bucket: str, object_key: str, expires: int = 900) -> str:
        pass
