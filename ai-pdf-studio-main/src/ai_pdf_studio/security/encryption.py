import base64
import os


class EncryptionError(ValueError):
    """Raised when encrypted application data cannot be opened."""


class SecretBox:
    """AES-GCM field encryption; the caller must keep the key in OS credential storage."""

    def __init__(self, key: bytes) -> None:
        if len(key) not in (16, 24, 32):
            raise ValueError("AES key must be 16, 24, or 32 bytes")
        try:
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            from cryptography.exceptions import InvalidTag
        except ImportError as exc:
            raise EncryptionError("cryptography is required for encrypted fields.") from exc
        self._aes = AESGCM(key)

    def encrypt(self, value: str, *, associated_data: bytes = b"") -> str:
        nonce = os.urandom(12)
        token = nonce + self._aes.encrypt(nonce, value.encode(), associated_data)
        return base64.urlsafe_b64encode(token).decode()

    def decrypt(self, token: str, *, associated_data: bytes = b"") -> str:
        try:
            raw = base64.urlsafe_b64decode(token)
            return self._aes.decrypt(raw[:12], raw[12:], associated_data).decode()
        except (ValueError, InvalidTag, UnicodeDecodeError) as exc:
            raise EncryptionError("Encrypted value could not be decrypted.") from exc
