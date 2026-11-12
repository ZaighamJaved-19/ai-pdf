from dataclasses import dataclass
import io
from pathlib import Path
import shutil
import subprocess

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
        output = output.expanduser().resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        images[0].save(output, "PDF", resolution=150.0, save_all=True, append_images=images[1:])
        return output
