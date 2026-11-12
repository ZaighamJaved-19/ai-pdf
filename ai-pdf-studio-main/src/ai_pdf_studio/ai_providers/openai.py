import json
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class OpenAIError(RuntimeError):
    """Raised when an OpenAI request fails or returns invalid data."""

    def __init__(self, message: str, *, kind: str = "Provider", status: int | None = None):
        super().__init__(message)
        self.kind = kind
        self.status = status


@dataclass(frozen=True, slots=True)
class ChatMessage:
    role: str
    content: str


class OpenAIClient:
    """Small dependency-free OpenAI API client with optional SSE streaming."""

    def __init__(
        self,
        api_key: str,
        *,
        base_url: str = "https://api.openai.com/v1",
        timeout: float = 30.0,
    ) -> None:
        if not api_key.strip():
            raise ValueError("api_key must not be empty")
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout

    def chat(
        self,
        messages: Sequence[ChatMessage],
        *,
        model: str = "gpt-4o-mini",
        temperature: float = 0.2,
        max_tokens: int = 1200,
        stream: bool = False,
    ) -> str | Iterator[str]:
        payload = {
            "model": model,
            "messages": [
                {"role": message.role, "content": message.content}
                for message in messages
            ],
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": stream,
        }
        if stream:
            return self.chat_stream(messages, model=model, temperature=temperature, max_tokens=max_tokens)
        response = self._request("/chat/completions", payload)
        try:
            return response["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise OpenAIError("OpenAI returned an invalid chat response.") from exc

    def chat_stream(
        self,
        messages: Sequence[ChatMessage],
        *,
        model: str = "gpt-4o-mini",
        temperature: float = 0.2,
        max_tokens: int = 1200,
    ) -> Iterator[str]:
        payload = {
            "model": model,
            "messages": [
                {"role": message.role, "content": message.content}
                for message in messages
            ],
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": True,
        }
        request = self._request_object("/chat/completions", payload)
        try:
            response = urlopen(request, timeout=self._timeout)
        except HTTPError as exc:
            raise self._http_error(exc) from exc
        except (URLError, TimeoutError) as exc:
            raise OpenAIError("OpenAI streaming request failed.", kind="Outage") from exc
        try:
            for raw_line in response:
                line = raw_line.decode("utf-8").strip()
                if not line.startswith("data: "):
                    continue
                data = line[6:]
                if data == "[DONE]":
                    break
                try:
                    event = json.loads(data)
                    content = event["choices"][0]["delta"].get("content")
                except (KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
                    raise OpenAIError("OpenAI returned invalid streaming data.") from exc
                if content:
                    yield str(content)
        finally:
            response.close()

    @staticmethod
    def _http_error(exc: HTTPError) -> OpenAIError:
        kind = {
            401: "InvalidKey",
            402: "NoCredits",
            404: "MissingModel",
            429: "RateLimit",
            500: "Outage",
            502: "Outage",
            503: "Outage",
        }.get(exc.code, "Provider")
        return OpenAIError(f"OpenAI request failed ({exc.code}).", kind=kind, status=exc.code)

    def embeddings(
        self, texts: Sequence[str], *, model: str = "text-embedding-3-small"
    ) -> tuple[tuple[float, ...], ...]:
        if not texts:
            return ()
        response = self._request(
            "/embeddings", {"model": model, "input": list(texts)}
        )
        try:
            items = sorted(response["data"], key=lambda item: item["index"])
            return tuple(tuple(float(value) for value in item["embedding"]) for item in items)
        except (KeyError, TypeError, ValueError) as exc:
            raise OpenAIError("OpenAI returned invalid embeddings.") from exc

    def _request(self, path: str, payload: dict[str, object]) -> dict[str, object]:
        request = self._request_object(path, payload)
        try:
            with urlopen(request, timeout=self._timeout) as response:
                return json.load(response)
        except HTTPError as exc:
            raise self._http_error(exc) from exc
        except (URLError, TimeoutError) as exc:
            raise OpenAIError("OpenAI request failed.", kind="Outage") from exc
        except json.JSONDecodeError as exc:
            raise OpenAIError("OpenAI returned invalid JSON.", kind="Provider") from exc

    def _request_object(self, path: str, payload: dict[str, object]) -> Request:
        return Request(
            f"{self._base_url}{path}",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )

