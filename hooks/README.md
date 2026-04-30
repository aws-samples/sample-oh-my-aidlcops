# OMA Hooks — Tier-0 Keyword Triggers

This directory contains hook scripts that enable automatic Tier-0 workflow detection in Claude Code.

## Setup

### 1. Install hooks (automated via `oma setup` or `install/claude.sh`)

Either `oma setup` (preferred) or the direct `scripts/install/claude.sh` script automatically:
- Copies `.omao/triggers.json` to user projects
- Makes hook scripts executable
- Provides instructions for wiring hooks in `.claude/settings.json`

### 2. Wire hooks in `.claude/settings.json`

Add the following to your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/user-prompt-submit.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Behavior

### `user-prompt-submit.sh`

Triggered on every user prompt. Reads `.omao/triggers.json` and checks for keyword matches:

- **Keyword detection**: Case-insensitive matching against trigger keywords
- **Context validation**: Ensures required context tokens are present (e.g., "autopilot" requires "aidlc")
- **Output**: Emits `additionalContext` JSON with suggested command if a match is found
- **Kill switch**: Set `OMA_DISABLE_TRIGGERS=1` to disable

Example trigger detection:
```
User: "Let me run autopilot on this AIDLC feature"
→ Detects "autopilot" + "aidlc" context
→ Suggests /oma:autopilot
```

### `session-start.sh`

Triggered at session start. Injects project context:

- **Active mode reminder**: Reads `.omao/state/active-mode` and warns if a Tier-0 workflow is running
- **Project memory**: Loads `.omao/project-memory.json` content
- **Command reference**: Lists all available OMA Tier-0 commands
- **Kill switch**: Set `OMA_DISABLE_TRIGGERS=1` to disable

## Triggers Catalog

See `.omao/triggers.json` for the full list. Current triggers:

| Keyword | Context Required | Command | Description |
|---------|------------------|---------|-------------|
| autopilot | aidlc | /oma:autopilot | AIDLC full-loop autopilot |
| agenticops | - | /oma:agenticops | Operations mode |
| self-improving | - | /oma:self-improving | Feedback loop runner |
| aidlc | - | /oma:aidlc-loop | Single feature AIDLC |
| eks-agentic, platform-bootstrap | - | /oma:platform-bootstrap | Platform bootstrap |
| inception | - | /oma:inception | AIDLC Phase 1 |
| construction | - | /oma:construction | AIDLC Phase 2 |
| cancel | - | /oma:cancel | Terminate active mode |

## Troubleshooting

### Triggers not firing

1. Check `.omao/triggers.json` exists in project root
2. Verify hooks are wired in `.claude/settings.json`
3. Ensure scripts are executable: `chmod +x hooks/*.sh`
4. Check `OMA_DISABLE_TRIGGERS` is not set to `1`
5. Verify `jq` is installed: `which jq`

### Testing hooks manually

```bash
# Test user-prompt-submit
echo '{"prompt":"let me run autopilot on aidlc"}' | bash hooks/user-prompt-submit.sh

# Test session-start
bash hooks/session-start.sh
```

### Debug mode

```bash
# Run with debug output
bash -x hooks/user-prompt-submit.sh <<< '{"prompt":"test autopilot aidlc"}'
```

## Implementation Notes

- **POSIX compatibility**: Scripts use `bash` but follow POSIX patterns for portability
- **Graceful degradation**: Missing `jq`, missing `triggers.json`, or parse errors exit cleanly
- **No side effects**: Hooks only emit JSON to stdout, never modify files
- **Security**: No `eval`, no external network calls, sandboxed execution
