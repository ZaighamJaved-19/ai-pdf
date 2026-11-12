from pathlib import Path
import shutil
import subprocess


class ConversionError(RuntimeError):
    """Raised when an external conversion engine is unavailable or fails."""


class ConversionService:
    def __init__(self, executable: str | None = None) -> None:
        self._executable = executable or shutil.which("libreoffice") or shutil.which("soffice")

    def to_pdf(self, source: Path, output_directory: Path) -> Path:
        return self._convert(source, output_directory)

    def from_pdf(self, source: Path, output: Path, *, format: str = "txt") -> Path:
        if format != "txt":
            raise ConversionError("PDF export currently supports only text format.")
        from ai_pdf_studio.pdf import PdfService

        pages = PdfService().extract_text(source)
        output = output.expanduser().resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            "\n\n".join(f"[Page {page.page_number}]\n{page.text}" for page in pages),
            encoding="utf-8",
        )
        return output

    def _convert(self, source: Path, output_directory: Path) -> Path:
        if self._executable is None:
            raise ConversionError("LibreOffice is required for office-to-PDF conversion.")
        output_directory = output_directory.expanduser().resolve()
        output_directory.mkdir(parents=True, exist_ok=True)
        try:
            result = subprocess.run(
                [self._executable, "--headless", "--convert-to", "pdf",
                 "--outdir", str(output_directory), str(source)],
                capture_output=True,
                text=True,
                check=False,
                timeout=180,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise ConversionError("Conversion process failed.") from exc
        output = output_directory / f"{source.stem}.pdf"
        if result.returncode or not output.is_file():
            raise ConversionError(result.stderr.strip() or "Conversion failed.")
        return output
