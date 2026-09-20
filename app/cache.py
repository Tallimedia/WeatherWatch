"""A small in-process TTL cache.

Deliberately not a database (RESEARCH.md §16): FMI is the source of truth and
serves history perfectly well, so nothing here needs to persist. This exists
only to keep repeated requests off FMI's service.
"""

from __future__ import annotations
import threading
import time
from typing import Any, Callable


class TTLCache:
    def __init__(self) -> None:
        self._data: dict[str, tuple[float, Any]] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> Any | None:
        with self._lock:
            hit = self._data.get(key)
            if hit is None:
                return None
            expires_at, value = hit
            if expires_at < time.monotonic():
                self._data.pop(key, None)
                return None
            return value

    def set(self, key: str, value: Any, ttl: int) -> None:
        with self._lock:
            self._data[key] = (time.monotonic() + ttl, value)

    async def aget_or_set(self, key: str, ttl: int, factory: Callable) -> Any:
        cached = self.get(key)
        if cached is not None:
            return cached
        value = await factory()
        self.set(key, value, ttl)
        return value


cache = TTLCache()
