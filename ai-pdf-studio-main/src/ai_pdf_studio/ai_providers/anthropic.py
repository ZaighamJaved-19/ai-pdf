import json
from collections.abc import Iterator, Sequence
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .openai import ChatMessage
from .base import ProviderError


class AnthropicClient:
    """Minimal provider adapter for Anthropic's Messages API."""

    provider_id = "anthropic"

    def __init__(self, api_key: str, *, timeout: float = 30.0) -> None:
        if not api_key.strip():
            raise ValueError("api_key must not be empty")
        self._api_key = api_key
        self._timeout = timeout

    def chat(
        self,
        messages: Sequence[ChatMessage],
        *,
        model: str,
        temperature: float = 0.2,
        max_tokens: int = 1200,
        stream: bool = False,
    ) -> str | Iterator[str]:
        system = "\n".join(message.content for message in messages if message.role == "system")
        payload = {
            "model": model,
            "max_tokens": max_tokens,
            "temperature": temperature,
            "system": system,
            "messages": [{"role": message.role, "content": message.content} for message in messages if message.role != "system"],
            "stream": stream,
        }
        if stream:
            return self.chat_stream(payload)
        request = Request(
            "https://api.anthropic.com/v1/messages",
            data=json.dumps(payload).encode(),
            headers={
                "x-api-key": self._api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=self._timeout) as response:
                body = json.load(response)
            return str(body["content"][0]["text"])
        except HTTPError as exc:
            kind = {401: "InvalidKey", 402: "NoCredits", 404: "MissingModel", 429: "RateLimit", 500: "Outage", 529: "Outage"}.get(exc.code, "Provider")
            raise ProviderError(f"Anthropic request failed ({exc.code}).", kind=kind, status=exc.code) from exc
        except (URLError, TimeoutError) as exc:
            raise ProviderError("Anthropic request failed.", kind="Outage") from exc
        except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
            raise ProviderError("Anthropic returned an invalid response.", kind="Provider") from exc

    def chat_stream(self, payload: dict[str, object]) -> Iterator[str]:
        request = Request(
            "https://api.anthropic.com/v1/messages",
            data=json.dumps(payload).encode(),
            headers={
                "x-api-key": self._api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            method="POST",
        )
        try:
            response = urlopen(request, timeout=self._timeout)
        except HTTPError as exc:
            raise self._http_error(exc) from exc
        except (URLError, TimeoutError) as exc:
            raise ProviderError("Anthropic streaming request failed.", kind="Outage") from exc
        try:
            for raw_line in response:
                line = raw_line.decode("utf-8").strip()
                if not line.startswith("data:"):
                    continue
                try:
                    event = json.loads(line[5:].strip())
                except json.JSONDecodeError as exc:
                    raise ProviderError("Anthropic returned invalid streaming data.", kind="Provider") from exc
                if event.get("type") == "content_block_delta":
                    text = event.get("delta", {}).get("text")
                    if text:
                        yield str(text)
        finally:
            response.close()

    @staticmethod
    def _http_error(exc: HTTPError) -> ProviderError:
        kind = {401: "InvalidKey", 402: "NoCredits", 404: "MissingModel", 429: "RateLimit", 500: "Outage", 529: "Outage"}.get(exc.code, "Provider")
        return ProviderError(f"Anthropic request failed ({exc.code}).", kind=kind, status=exc.code)

    def embeddings(self, texts: Sequence[str], *, model: str) -> tuple[tuple[float, ...], ...]:
        raise ProviderError("Anthropic does not provide embeddings through this adapter.", kind="Provider")
