from pathlib import Path
import shutil
import subprocess


class OcrError(RuntimeError):
    """Raised when the optional Tesseract OCR engine is unavailable or fails."""


class OcrService:
    def __init__(self, executable: str | None = None) -> None:
        self._executable = executable or shutil.which("tesseract")

    def recognize(self, image_path: Path, *, language: str = "eng") -> str:
        if self._executable is None:
            raise OcrError("Tesseract is not installed or is not on PATH.")
        if not image_path.is_file():
            raise OcrError(f"Image does not exist: {image_path}")
        try:
            result = subprocess.run(
                [self._executable, str(image_path), "stdout", "-l", language],
                capture_output=True,
                text=True,
                check=False,
                timeout=120,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise OcrError("OCR process failed.") from exc
        if result.returncode:
            raise OcrError(result.stderr.strip() or "OCR process failed.")
        return result.stdout
