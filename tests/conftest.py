"""Project-wide pytest fixtures and warning filters.

jsonschema>=4.18 deprecated ``RefResolver`` in favour of the new
``referencing`` package. The ontology and harness compiler still rely on
``RefResolver`` because the migration to ``referencing.Registry`` is tracked
for a later release. Until then we silence the DeprecationWarning so test
runs with ``-W error`` remain green.
"""

from __future__ import annotations

import warnings

warnings.filterwarnings(
    "ignore",
    category=DeprecationWarning,
    module=r"jsonschema(\..*)?",
)
