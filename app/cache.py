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

    Entries are swept on write, and the cache is capped. Expiry alone is not
    enough: an entry was only ever dropped when *its own key* was read again,
    so a key requested once and never again stayed resident for the life of
    the process. Keys embed caller-supplied values (place names, horizons,
    languages), so the number of distinct keys is effectively unbounded and
    memory grew monotonically whatever the TTLs said.
    """

    #: Enough for every place, station and horizon in real use; small enough
    #: that a caller enumerating place names cannot exhaust the container.
    MAX_ENTRIES = 512

    def __init__(self, max_entries: int | None = None) -> None:
        self._data: dict[str, tuple[float, Any, int]] = {}
        self._lock = threading.Lock()
        self._max = max_entries or self.MAX_ENTRIES

    def __len__(self) -> int:
        with self._lock:
            return len(self._data)

    def _evict(self) -> None:
        """Drop expired entries, then the soonest-to-expire until under cap.

        Caller holds the lock.
        """
        now = time.monotonic()
        for key in [k for k, (expires, _, _) in self._data.items() if expires < now]:
            self._data.pop(key, None)
        if len(self._data) < self._max:
            return
        ordered = sorted(self._data.items(), key=lambda kv: kv[1][0])
        for key, _ in ordered[: len(self._data) - self._max + 1]:
            self._data.pop(key, None)

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
            if key not in self._data and len(self._data) >= self._max:
                self._evict()
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
