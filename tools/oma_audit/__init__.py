"""oma_audit — append JSON-L audit events validated against the audit schema.

This package replaces the legacy ``echo >> aidlc-docs/audit.md`` pattern
used by plugin skills during v0.2. Dual-write is expected through v0.4;
Markdown path is removed in v0.5.
"""

from __future__ import annotations

from .append import AuditValidationError, append_audit_event

__all__ = ["append_audit_event", "AuditValidationError"]
