from datetime import datetime, timezone
import json
from pathlib import Path


class Telemetry:
    """Opt-in, content-free JSONL event recorder."""

    def __init__(self, path: Path, *, enabled: bool = False) -> None:
        self._path = path
        self._enabled = enabled

    def record(self, name: str, **properties: str | int | float | bool) -> None:
        if not self._enabled:
            return
        event = {
            "name": name,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "properties": properties,
        }
        self._path.parent.mkdir(parents=True, exist_ok=True)
        with self._path.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(event, sort_keys=True) + "\n")
