from dataclasses import dataclass
from difflib import unified_diff
from pathlib import Path

from ai_pdf_studio.pdf import PdfService


@dataclass(frozen=True, slots=True)
class CompareResult:
    left: Path
    right: Path
    changed: bool
    diff: str


class CompareService:
    def compare_text(self, left: Path, right: Path) -> CompareResult:
        left_pages = PdfService().extract_text(left)
        right_pages = PdfService().extract_text(right)
        left_text = "\n".join(page.text for page in left_pages).splitlines()
        right_text = "\n".join(page.text for page in right_pages).splitlines()
        diff = "\n".join(unified_diff(left_text, right_text, fromfile=str(left), tofile=str(right)))
        return CompareResult(left, right, bool(diff), diff)
