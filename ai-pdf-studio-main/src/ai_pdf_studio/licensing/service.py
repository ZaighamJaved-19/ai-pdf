from dataclasses import dataclass
import base64
import hashlib
import hmac
import json
import time


class LicenseError(ValueError):
    """Raised for invalid or expired entitlements."""


@dataclass(frozen=True, slots=True)
class Entitlement:
    product_id: str
    expires_at: int
    features: tuple[str, ...]

    def permits(self, feature: str) -> bool:
        return self.expires_at >= int(time.time()) and feature in self.features


class LicenseService:
    """Verifies owner-issued HMAC entitlements; Store receipt integration stays native."""

    def __init__(self, signing_key: bytes) -> None:
        if not signing_key:
            raise ValueError("signing_key must not be empty")
        self._key = signing_key

    def issue(self, product_id: str, *, expires_at: int, features: tuple[str, ...]) -> str:
        payload = json.dumps(
            {"product_id": product_id, "expires_at": expires_at, "features": features},
            separators=(",", ":"), sort_keys=True,
        ).encode()
        encoded = base64.urlsafe_b64encode(payload).decode().rstrip("=")
        signature = hmac.new(self._key, encoded.encode(), hashlib.sha256).hexdigest()
        return f"{encoded}.{signature}"

    def verify(self, token: str) -> Entitlement:
        try:
            encoded, signature = token.split(".", 1)
            expected = hmac.new(self._key, encoded.encode(), hashlib.sha256).hexdigest()
            if not hmac.compare_digest(signature, expected):
                raise LicenseError("Invalid entitlement signature.")
            payload = json.loads(base64.urlsafe_b64decode(encoded + "=="))
            entitlement = Entitlement(
                payload["product_id"], int(payload["expires_at"]), tuple(payload["features"])
            )
        except (ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
            raise LicenseError("Invalid entitlement.") from exc
        if entitlement.expires_at < int(time.time()):
            raise LicenseError("Entitlement has expired.")
        return entitlement
