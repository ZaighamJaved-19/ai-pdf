from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from ai_pdf_studio.ai_providers import ChatMessage, ProviderAdapter


SUMMARY_MODES = (
    "brief",
    "executive",
    "detailed",
    "bullet",
    "outline",
    "academic",
    "action_items",
    "one_sentence",
)
DIFFICULTIES = ("easy", "medium", "hard")
TRANSLATION_LANGUAGES = (
    "English",
    "Spanish",
    "French",
    "German",
    "Italian",
    "Portuguese",
    "Arabic",
)
WRITING_OPERATIONS = ("rewrite", "simplify", "grammar", "tone", "explain_terms")


class AiToolError(ValueError):
    """Raised when an AI tool request is invalid or cannot be parsed."""


@dataclass(frozen=True, slots=True)
class AiToolRequest:
    operation: str
    text: str
    mode: str | None = None
    difficulty: str = "medium"
    language: str = "English"
    tone: str = "professional"
    instruction: str = ""


@dataclass(frozen=True, slots=True)
class AiToolResult:
    operation: str
    title: str
    content: str
    items: tuple[dict[str, Any], ...] = ()

    def as_dict(self) -> dict[str, Any]:
        return {
            "operation": self.operation,
            "title": self.title,
            "content": self.content,
            "items": list(self.items),
        }


class AiToolsService:
    """Builds constrained prompts and normalizes generated tool results."""

    def generate(
        self,
        request: AiToolRequest,
        provider: ProviderAdapter,
        *,
        model: str,
        temperature: float = 0.2,
        max_tokens: int = 1200,
    ) -> AiToolResult:
        self._validate(request)
        prompt, title, expects_json = self._prompt(request)
        response = provider.chat(
            [
                ChatMessage(
                    "system",
                    "You are a careful document assistant. Use only the supplied text. "
                    "Do not invent facts. Preserve the user's original text; return only "
                    "the requested result.",
                ),
                ChatMessage("user", prompt),
            ],
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        if not isinstance(response, str):
            raise AiToolError("The provider returned a stream for a non-streaming tool.")
        if expects_json:
            return self._structured_result(request.operation, title, response)
        return AiToolResult(request.operation, title, response.strip())

    def _prompt(self, request: AiToolRequest) -> tuple[str, str, bool]:
        if request.operation == "summary":
            mode = request.mode or "brief"
            return (
                f"Create a {mode.replace('_', ' ')} summary of this document. "
                "Keep important names, dates, figures, caveats, and page references when present.\n\n"
                f"DOCUMENT:\n{request.text}",
                f"{mode.replace('_', ' ').title()} Summary",
                False,
            )
        if request.operation == "notes":
            return (
                "Create useful study notes with headings, key concepts, definitions, "
                "and actionable takeaways. Use concise Markdown.\n\n"
                f"DOCUMENT:\n{request.text}",
                "Generated notes",
                False,
            )
        if request.operation in ("quiz", "flashcards"):
            count = 10
            kind = "multiple-choice quiz questions" if request.operation == "quiz" else "flashcards"
            schema = (
                '{"items":[{"question":"...","answer":"...","options":["..."],'
                '"explanation":"..."}]}'
                if request.operation == "quiz"
                else '{"items":[{"front":"...","back":"..."}]}'
            )
            return (
                f"Create {count} {kind} at {request.difficulty} difficulty. "
                f"Return valid JSON only using this schema: {schema}. "
                "Every item must be answerable from the document.\n\n"
                f"DOCUMENT:\n{request.text}",
                f"{request.difficulty.title()} {request.operation.title()}",
                True,
            )
        if request.operation == "translate":
            return (
                f"Translate the following text into {request.language}. Preserve meaning, "
                "formatting, names, numbers, and paragraph breaks. Return only the translation.\n\n"
                f"TEXT:\n{request.text}",
                f"Translation to {request.language}",
                False,
            )
        if request.operation == "writing":
            operation = request.mode or "rewrite"
            task = {
                "rewrite": "rewrite for clarity while preserving meaning",
                "simplify": "simplify the language without removing important meaning",
                "grammar": "correct grammar, spelling, and punctuation",
                "tone": f"rewrite in a {request.tone} tone",
                "explain_terms": "explain difficult terms after the original passage in a separate section",
            }[operation]
            return (
                f"{task}. Never claim the original was changed. Return only the improved "
                "or explained version in Markdown.\n\n"
                f"ADDITIONAL INSTRUCTION:\n{request.instruction}\n\nTEXT:\n{request.text}",
                f"Writing assistant: {operation.replace('_', ' ').title()}",
                False,
            )
        raise AiToolError(f"Unsupported AI tool operation: {request.operation}")

    @staticmethod
    def _validate(request: AiToolRequest) -> None:
        if not request.text.strip():
            raise AiToolError("Text is required.")
        if request.operation == "summary" and request.mode not in SUMMARY_MODES:
            raise AiToolError("Unsupported summary mode.")
        if request.operation in ("quiz", "flashcards") and request.difficulty not in DIFFICULTIES:
            raise AiToolError("Unsupported difficulty.")
        if request.operation == "translate" and request.language not in TRANSLATION_LANGUAGES:
            raise AiToolError("Unsupported translation language.")
        if request.operation == "writing" and request.mode not in WRITING_OPERATIONS:
            raise AiToolError("Unsupported writing operation.")

    @staticmethod
    def _structured_result(operation: str, title: str, response: str) -> AiToolResult:
        raw = response.strip().removeprefix("```json").removesuffix("```").strip()
        try:
            decoded = json.loads(raw)
            items = decoded.get("items") if isinstance(decoded, dict) else None
            if not isinstance(items, list):
                raise ValueError
            normalized = tuple(item for item in items if isinstance(item, dict))
            if not normalized:
                raise ValueError
            return AiToolResult(operation, title, json.dumps(normalized, ensure_ascii=False), normalized)
        except (json.JSONDecodeError, TypeError, ValueError):
            return AiToolResult(operation, title, response.strip())
