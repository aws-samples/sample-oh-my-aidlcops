#!/usr/bin/env python3
"""Run the non-OPA harness test modules without pytest installed.

This dev box has no pytest/pip. To still get fresh evidence that the existing
test suite passes after the OPA removal, we install a tiny in-process `pytest`
shim (tmp_path, raises, mark.parametrize, mark.skipif, fixture) into sys.modules,
import each target test module, and execute its test_* functions, expanding
parametrize cases. Exit 0 iff every collected test passes.

Run: python3 tests/standalone/run_pytest_subset.py
"""
from __future__ import annotations

import importlib.util
import inspect
import shutil
import sys
import tempfile
import traceback
import types
from contextlib import contextmanager
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))


# ---- minimal pytest shim ---------------------------------------------------
class _Raises:
    def __init__(self, exc, match=None):
        self.exc = exc
        self.match = match

    def __enter__(self):
        return self

    def __exit__(self, et, ev, tb):
        import re as _re
        if et is None:
            raise AssertionError(f"DID NOT RAISE {self.exc!r}")
        if not issubclass(et, self.exc):
            return False  # propagate unexpected
        if self.match and not _re.search(self.match, str(ev)):
            raise AssertionError(f"raised {et.__name__} but message {ev!r} !~ /{self.match}/")
        return True  # swallow expected


class _Mark:
    def parametrize(self, argnames, argvalues):
        def deco(fn):
            fn._parametrize = (argnames, argvalues)
            return fn
        return deco

    def skipif(self, cond, reason=""):
        def deco(fn):
            fn._skip = bool(cond)
            fn._skip_reason = reason
            return fn
        return deco

    def __getattr__(self, _):
        # any other mark is a no-op decorator
        return lambda *a, **k: (lambda fn: fn)


def _fixture(*a, **k):
    def deco(fn):
        fn._is_fixture = True
        return fn
    return deco if not (a and callable(a[0])) else a[0]


pytest_shim = types.ModuleType("pytest")
pytest_shim.raises = lambda exc, match=None: _Raises(exc, match)
pytest_shim.mark = _Mark()
pytest_shim.fixture = _fixture
pytest_shim.skip = lambda reason="": (_ for _ in ()).throw(_Skip(reason))


class _Skip(Exception):
    pass


pytest_shim.Skipped = _Skip
sys.modules["pytest"] = pytest_shim


# ---- collection / execution ------------------------------------------------
TARGETS = [
    "tests/harness/test_compile_roundtrip.py",
    "tests/harness/test_dsl_schema.py",
    "tests/harness/test_workflows.py",
    "tests/harness/test_ai_infra_compile.py",
    "tests/harness/test_telemetry_schema.py",
]

passed = 0
failed: list[str] = []
skipped = 0


def _load_module(path: Path):
    name = "t_" + path.stem
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _call(fn, label):
    global passed, skipped
    if getattr(fn, "_skip", False):
        skipped += 1
        print(f"[SKIP] {label} ({getattr(fn, '_skip_reason', '')})")
        return
    sig = inspect.signature(fn)
    kwargs = {}
    tmp = None
    if "tmp_path" in sig.parameters:
        tmp = Path(tempfile.mkdtemp())
        kwargs["tmp_path"] = tmp
    try:
        fn(**kwargs)
        passed += 1
        print(f"[PASS] {label}")
    except _Skip as s:
        skipped += 1
        print(f"[SKIP] {label} ({s})")
    except Exception:
        failed.append(label)
        print(f"[FAIL] {label}")
        traceback.print_exc()
    finally:
        if tmp and tmp.exists():
            shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    for rel in TARGETS:
        path = REPO / rel
        if not path.exists():
            print(f"[SKIP] {rel} (missing)")
            continue
        mod = _load_module(path)
        for nm, fn in sorted(vars(mod).items()):
            if not (nm.startswith("test_") and callable(fn)):
                continue
            if hasattr(fn, "_parametrize"):
                argnames, argvalues = fn._parametrize
                names = [a.strip() for a in argnames.split(",")] if isinstance(argnames, str) else list(argnames)
                for i, val in enumerate(argvalues):
                    vals = val if (len(names) > 1 and isinstance(val, (tuple, list))) else (val,)
                    bound = (lambda f, vv: (lambda **kw: f(**kw, **dict(zip(names, vv)))))(fn, vals)
                    # carry skip flag
                    bound._skip = getattr(fn, "_skip", False)
                    _call(bound, f"{rel}::{nm}[{i}]")
            else:
                _call(fn, f"{rel}::{nm}")
    total = passed + len(failed) + skipped
    print(f"\n{passed}/{total} passed, {len(failed)} failed, {skipped} skipped")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
