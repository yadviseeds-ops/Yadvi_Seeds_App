"""
Thread-safe, in-memory sliding-window rate limiter using Python standard library.
Enforces request rate limits per client IP without requiring Redis or external services.

Trust Assumptions & Client IP Extraction:
- In Google Cloud Run, the Google Front End (GFE) terminates TLS and appends the
  client's actual remote IP address to the end of the X-Forwarded-For header.
- If an untrusted caller sends a spoofed X-Forwarded-For header (e.g. '1.1.1.1'),
  GFE appends the actual connecting IP: '1.1.1.1, <actual_client_ip>'.
  Therefore, the rightmost non-empty IP entry is the verified connecting IP.
- In direct connections or local development without proxies, request.client.host is used.
- If the IP cannot be determined, a fallback identifier 'unknown_client_ip' is assigned
  with its own isolated rate limit bucket to prevent open access or shared starvation.

Limitations:
- Memory is local to the container process. State does NOT persist across container
  restarts or cold starts, and is not shared across multiple scaled Cloud Run instances.
- This provides application-level defense-in-depth against automated brute-force attacks,
  not distributed L7 DDoS mitigation (which requires Cloud Armor / CDN edge protection).
"""

import time
import threading
from collections import defaultdict, deque
from typing import Tuple
from fastapi import Request
import logging

logger = logging.getLogger("yadvi_rate_limiter")


def get_client_ip(request: Request) -> str:
    """
    Safely extracts client IP address.
    Takes the rightmost IP in X-Forwarded-For (appended by Google Cloud Run GFE proxy),
    or falls back to request.client.host in local dev/tests.
    """
    xff = request.headers.get("x-forwarded-for")
    if xff:
        ips = [ip.strip() for ip in xff.split(",") if ip.strip()]
        if ips:
            return ips[-1]

    if request.client and request.client.host:
        return request.client.host

    return "unknown_client_ip"


class SlidingWindowRateLimiter:
    """
    Thread-safe in-memory sliding-window rate limiter.
    Maintains a deque of timestamps for each key.
    """
    def __init__(self, max_keys: int = 20000):
        self._lock = threading.Lock()
        self._windows = defaultdict(deque)
        self._max_keys = max_keys

    def is_allowed(self, key: str, max_requests: int, window_seconds: int) -> Tuple[bool, int]:
        """
        Checks if an action is allowed under the sliding window without recording a hit.
        Returns:
            (is_allowed: bool, retry_after_seconds: int)
        """
        now = time.time()
        cutoff = now - window_seconds

        with self._lock:
            queue = self._windows[key]

            # Prune timestamps older than window
            while queue and queue[0] <= cutoff:
                queue.popleft()

            if len(queue) >= max_requests:
                oldest = queue[0]
                retry_after = max(1, int(oldest + window_seconds - now))
                return False, retry_after

            return True, 0

    def record_hit(self, key: str, window_seconds: int):
        """Records a timestamp hit for the given key."""
        now = time.time()
        cutoff = now - window_seconds

        with self._lock:
            if len(self._windows) > self._max_keys:
                self._prune_all(now)

            queue = self._windows[key]
            while queue and queue[0] <= cutoff:
                queue.popleft()
            queue.append(now)

    def check_and_record(self, key: str, max_requests: int, window_seconds: int) -> Tuple[bool, int]:
        """
        Atomically checks if allowed and records the hit if allowed.
        Returns:
            (is_allowed: bool, retry_after_seconds: int)
        """
        now = time.time()
        cutoff = now - window_seconds

        with self._lock:
            if len(self._windows) > self._max_keys:
                self._prune_all(now)

            queue = self._windows[key]
            while queue and queue[0] <= cutoff:
                queue.popleft()

            if len(queue) >= max_requests:
                oldest = queue[0]
                retry_after = max(1, int(oldest + window_seconds - now))
                return False, retry_after

            queue.append(now)
            return True, 0

    def _prune_all(self, now: float):
        """Cleans up empty or stale deques across all keys to prevent unbounded memory growth."""
        to_delete = []
        for k, q in self._windows.items():
            while q and q[0] <= (now - 3600):
                q.popleft()
            if not q:
                to_delete.append(k)
        for k in to_delete:
            del self._windows[k]

    def reset(self):
        """Resets all tracked rate limits. Useful for test isolation."""
        with self._lock:
            self._windows.clear()


# Global rate limiter instances for authentication endpoints
verify_user_limiter = SlidingWindowRateLimiter()   # 10 req / 60s
login_failure_limiter = SlidingWindowRateLimiter() # 5 failed req / 300s
request_otp_limiter = SlidingWindowRateLimiter()   # 3 req / 600s
