#!/usr/bin/env python3
"""check-references.py — live HTTP verification for REFERENCES.md.

Walks the repo-root REFERENCES.md, extracts every `https://` URL, and
issues a HEAD (falling back to GET) with a 15 second timeout. Accepts
2xx responses plus the redirect codes the web treats as "present"
(301/302/307/308) and 429 (rate-limited — the target is alive).

Exits non-zero when any catalogue URL fails. Designed for a dedicated
weekly CI job so transient upstream outages do not block PRs; the
output is human-readable so a follow-up PR can patch the catalogue.

Uses only the Python stdlib (urllib) — no extra workflow dep.
"""

from __future__ import annotations

import argparse
import re
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterable

ACCEPTED_STATUS = {200, 201, 203, 204, 301, 302, 303, 307, 308, 429}
URL_PATTERN = re.compile(r"https?://[^\s\)<>\]\"'`]+", re.IGNORECASE)
DEFAULT_TIMEOUT = 15  # seconds
USER_AGENT = "oma-references-check/1.0 (+https://github.com/aws-samples/sample-oh-my-aidlcops)"


def extract_urls(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    urls: list[str] = []
    seen: set[str] = set()
    for raw in URL_PATTERN.findall(text):
        # Strip trailing punctuation markdown adds (`.` / `,` / `;`).
        url = raw.rstrip(".,;:!?")
        # Skip bare protocol strings ("https://" alone in prose) that
        # carry no host — they match the pattern but are not URLs.
        host = url.split("://", 1)[1] if "://" in url else ""
        if not host:
            continue
        if url in seen:
            continue
        seen.add(url)
        urls.append(url)
    return urls


def probe(url: str, timeout: int = DEFAULT_TIMEOUT) -> tuple[int, str]:
    """Return (status_code, diagnostic). status_code 0 = unexpected failure."""
    ctx = ssl.create_default_context()
    for method in ("HEAD", "GET"):
        try:
            req = urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
                return resp.status, f"{method} {resp.status}"
        except urllib.error.HTTPError as exc:
            # Some servers reject HEAD with 403/405/501 but accept GET.
            # Some CDNs (nvlpubs.nist.gov among them) return HEAD 404 for
            # PDFs that are perfectly reachable via GET — so we fall back
            # to GET on 404 as well and let the second attempt decide.
            if method == "HEAD" and exc.code in (403, 404, 405, 501):
                continue
            return exc.code, f"{method} {exc.code} {exc.reason}"
        except urllib.error.URLError as exc:
            if method == "HEAD":
                continue
            return 0, f"{method} network error: {exc.reason}"
        except TimeoutError:
            if method == "HEAD":
                continue
            return 0, f"{method} timeout after {timeout}s"
        except Exception as exc:  # noqa: BLE001
            return 0, f"{method} unexpected error: {type(exc).__name__}: {exc}"
    return 0, "exhausted methods"


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "path",
        nargs="?",
        default=str(Path(__file__).resolve().parents[2] / "REFERENCES.md"),
        help="REFERENCES.md path (default: repo root)",
    )
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    parser.add_argument(
        "--skip-own-pages",
        action="store_true",
        help="Skip aws-samples.github.io/sample-oh-my-aidlcops/ URLs that may not exist yet",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)

    ref_path = Path(args.path)
    if not ref_path.is_file():
        print(f"error: {ref_path} not found", file=sys.stderr)
        return 2

    urls = extract_urls(ref_path)
    if not urls:
        print(f"error: no URLs extracted from {ref_path}", file=sys.stderr)
        return 2

    print(f"[check-references] {ref_path}: {len(urls)} unique URLs")
    failures: list[tuple[str, str]] = []
    for url in urls:
        if args.skip_own_pages and url.startswith(
            "https://aws-samples.github.io/sample-oh-my-aidlcops/"
        ):
            print(f"  SKIP {url}")
            continue
        status, diag = probe(url, timeout=args.timeout)
        ok = status in ACCEPTED_STATUS
        marker = "OK  " if ok else "FAIL"
        print(f"  {marker} {url} ({diag})")
        if not ok:
            failures.append((url, diag))

    print()
    if failures:
        print(f"[check-references] {len(failures)} failure(s):", file=sys.stderr)
        for url, diag in failures:
            print(f"  - {url}: {diag}", file=sys.stderr)
        return 1
    print(f"[check-references] all {len(urls)} URLs OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
