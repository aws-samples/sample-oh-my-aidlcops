"""oma-compile: translate *.oma.yaml into native Claude Code / Kiro files.

The DSL is a build-time translator. Native runtimes consume the emitted
files unchanged, so marketplace installs keep working even when the
compiler is not present on the end user's machine.
"""

from .compile import CompileError, compile_plugin, compile_workspace

__all__ = ["CompileError", "compile_plugin", "compile_workspace"]
