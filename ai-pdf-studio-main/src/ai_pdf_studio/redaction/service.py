from dataclasses import dataclass
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from pypdf import PdfReader


class RedactionError(RuntimeError):
    """Raised when true PDF redaction cannot be completed safely."""


@dataclass(frozen=True, slots=True)
class RedactionRequest:
    page_number: int
    left: float
    bottom: float
    right: float
    top: float


class RedactionService:
    """Uses PDFium rasterization when installed; never pretends an overlay is redaction."""

    def redact(self, input_path: Path, output: Path, requests: tuple[RedactionRequest, ...]) -> Path:
        if not requests:
            raise ValueError("At least one redaction request is required")
        executable = shutil.which("pdftoppm")
        if executable is None:
            raise RedactionError(
                "True redaction requires pdftoppm and Pillow."
            )
        try:
            from PIL import Image, ImageDraw
        except ImportError as exc:
            raise RedactionError("True redaction requires Pillow.") from exc
        input_path = input_path.expanduser().resolve()
        output = output.expanduser().resolve()
        if input_path == output:
            raise RedactionError("Redaction must write a new PDF; the source cannot be overwritten.")
        if not input_path.is_file():
            raise RedactionError(f"PDF does not exist: {input_path}")
        if input_path.stat().st_size > 512 * 1024 * 1024:
            raise RedactionError("PDF exceeds the safe 512 MB processing limit.")
        reader = PdfReader(str(input_path), strict=False)
        requests_by_page: dict[int, list[RedactionRequest]] = {}
        for request in requests:
            if request.page_number < 1 or request.page_number > len(reader.pages):
                raise RedactionError(f"Page out of range: {request.page_number}")
            requests_by_page.setdefault(request.page_number, []).append(request)
        images = []
        for page_number, page in enumerate(reader.pages, start=1):
            try:
                rendered = subprocess.run(
                    [executable, "-png", "-r", "150", "-f", str(page_number),
                     "-l", str(page_number), str(input_path), "-"],
                    capture_output=True,
                    check=False,
                    timeout=120,
                )
            except (OSError, subprocess.TimeoutExpired) as exc:
                raise RedactionError("PDF rasterization failed.") from exc
            if rendered.returncode:
                raise RedactionError("PDF rasterization failed.")
            image = Image.open(io.BytesIO(rendered.stdout)).convert("RGB")
            scale_x = image.width / float(page.mediabox.width)
            scale_y = image.height / float(page.mediabox.height)
            draw = ImageDraw.Draw(image)
            for request in requests_by_page.get(page_number, []):
                draw.rectangle(
                    (
                        request.left * scale_x,
                        image.height - request.top * scale_y,
                        request.right * scale_x,
                        image.height - request.bottom * scale_y,
                    ),
                    fill="black",
                )
            images.append(image)
        output.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix=".pdf-redaction-", suffix=".pdf", dir=output.parent)
        os.close(fd)
        temporary_path = Path(temporary)
        try:
            images[0].save(temporary_path, "PDF", resolution=150.0, save_all=True, append_images=images[1:])
            os.replace(temporary_path, output)
        finally:
            temporary_path.unlink(missing_ok=True)
        if any((page.extract_text() or "").strip() for page in PdfReader(str(output), strict=False).pages):
            raise RedactionError("Redaction verification failed: searchable text remains.")
        return output

    def redact_terms(self, input_path: Path, output: Path, terms: tuple[str, ...]) -> Path:
        """Redact matching pages completely, then verify no term remains searchable."""
        normalized = tuple(term.strip().casefold() for term in terms if term.strip())
        if not normalized:
            raise RedactionError("At least one search term is required.")
        reader = PdfReader(str(input_path), strict=False)
        requests = tuple(
            RedactionRequest(
                page_number=index,
                left=float(page.mediabox.left),
                bottom=float(page.mediabox.bottom),
                right=float(page.mediabox.right),
                top=float(page.mediabox.top),
            )
            for index, page in enumerate(reader.pages, start=1)
            if any(term in (page.extract_text() or "").casefold() for term in normalized)
        )
        if not requests:
            raise RedactionError("No matching text was found in the document.")
        result = self.redact(input_path, output, requests)
        verification_reader = PdfReader(str(result), strict=False)
        remaining = "\n".join(page.extract_text() or "" for page in verification_reader.pages).casefold()
        if any(term in remaining for term in normalized):
            raise RedactionError("Redaction verification failed: a search term remains.")
        return result
