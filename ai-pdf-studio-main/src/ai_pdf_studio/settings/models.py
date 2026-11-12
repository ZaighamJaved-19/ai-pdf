from dataclasses import dataclass
from enum import StrEnum


class Theme(StrEnum):
    SYSTEM = "system"
    LIGHT = "light"
    DARK = "dark"


@dataclass(slots=True)
class AppSettings:
    theme: Theme = Theme.SYSTEM
    default_zoom: float = 1.0
    telemetry_enabled: bool = False

    def __post_init__(self) -> None:
        if self.default_zoom <= 0:
            raise ValueError("default_zoom must be positive")


@dataclass(slots=True)
class OnboardingState:
    completed: bool = False
    selected_provider: str | None = None

    def finish(self, provider: str | None = None) -> None:
        self.selected_provider = provider
        self.completed = True
