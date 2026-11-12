from pathlib import Path
import time

from ai_pdf_studio.library import DocumentRepository
from ai_pdf_studio.licensing import LicenseService
from ai_pdf_studio.security import SecretBox
from ai_pdf_studio.settings import AppSettings, OnboardingState, Theme
from ai_pdf_studio.telemetry import Telemetry


def test_library_tags_and_workspaces(tmp_path: Path) -> None:
    repository = DocumentRepository(tmp_path / "library.db")
    document = tmp_path / "document.pdf"
    repository.set_tags(document, {"research", "important"})
    repository.create_workspace("Review")
    repository.add_to_workspace("Review", document)

    assert repository.tags(document) == ("important", "research")
    assert repository.workspace_documents("Review") == (document.resolve(),)
    repository.close()


def test_secret_box_round_trip_and_license_verification(tmp_path: Path) -> None:
    box = SecretBox(b"0" * 32)
    token = box.encrypt("private note")
    assert box.decrypt(token) == "private note"

    licenses = LicenseService(b"signing-key")
    license_token = licenses.issue(
        "ai-pdf-pro", expires_at=int(time.time()) + 60, features=("ocr",)
    )
    assert licenses.verify(license_token).permits("ocr")


def test_settings_onboarding_and_opt_in_telemetry(tmp_path: Path) -> None:
    settings = AppSettings(theme=Theme.DARK, default_zoom=1.25)
    onboarding = OnboardingState()
    onboarding.finish("openai")
    telemetry = Telemetry(tmp_path / "events.jsonl", enabled=True)
    telemetry.record("opened", page_count=2)

    assert settings.theme is Theme.DARK
    assert onboarding.completed and onboarding.selected_provider == "openai"
    assert "opened" in (tmp_path / "events.jsonl").read_text()
