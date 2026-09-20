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
    """Entries carry the wall-clock time they were fetched.

    Without that, a cached response looks as fresh as a live one — the caller
    cannot tell a reading fetched two seconds ago from one fetched four minutes
    ago, which is the difference the `retrieved` field exists to show.
    """

    def __init__(self) -> None:
        self._data: dict[str, tuple[float, Any, int]] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> Any | None:
        entry = self.get_entry(key)
        return None if entry is None else entry[0]

    def get_entry(self, key: str) -> tuple[Any, int] | None:
        """The cached value plus the epoch second it was fetched from upstream."""
        with self._lock:
            hit = self._data.get(key)
            if hit is None:
                return None
            expires_at, value, fetched_at = hit
            if expires_at < time.monotonic():
                self._data.pop(key, None)
                return None
            return value, fetched_at

    def set(self, key: str, value: Any, ttl: int) -> None:
        with self._lock:
            self._data[key] = (time.monotonic() + ttl, value, int(time.time()))

    async def aget_or_set(self, key: str, ttl: int, factory: Callable) -> Any:
        value, _ = await self.aget_or_set_entry(key, ttl, factory)
        return value

    async def aget_or_set_entry(self, key: str, ttl: int, factory: Callable) -> tuple[Any, int]:
        cached = self.get_entry(key)
        if cached is not None:
            return cached
        value = await factory()
        self.set(key, value, ttl)
        entry = self.get_entry(key)
        return entry if entry is not None else (value, int(time.time()))


cache = TTLCache()
