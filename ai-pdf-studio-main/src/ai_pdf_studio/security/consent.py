from dataclasses import dataclass
from datetime import datetime, timezone


class ConsentError(ValueError):
    """Raised when an online operation is not explicitly authorized."""


@dataclass(frozen=True, slots=True)
class Consent:
    provider_id: str
    document_id: str
    scope: str
    granted_at: datetime

    @classmethod
    def grant(cls, provider_id: str, document_id: str, scope: str) -> "Consent":
        if not provider_id.strip() or not document_id.strip() or not scope.strip():
            raise ConsentError("provider_id, document_id, and scope are required")
        return cls(provider_id, document_id, scope, datetime.now(timezone.utc))

    def permits(self, provider_id: str, document_id: str, scope: str) -> bool:
        return (
            self.provider_id == provider_id
            and self.document_id == document_id
            and self.scope == scope
        )


def require_consent(
    consent: Consent | None,
    *,
    provider_id: str,
    document_id: str,
    scope: str,
) -> None:
    if consent is None or not consent.permits(provider_id, document_id, scope):
        raise ConsentError(
            f"Consent is required to send document {document_id!r} to {provider_id!r}."
        )
