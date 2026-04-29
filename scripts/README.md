# oh-my-aidlcops — scripts/

Operational scripts for installing, initializing, validating, and syncing the
oh-my-aidlcops (OMA) plugin marketplace.

All scripts are idempotent. Re-running them is always safe and will only apply
the missing changes. Every script supports `--help`.

## Scripts

| Script | Purpose |
|---|---|
| `install-claude.sh`     | Install OMA into the current user's `~/.claude/` directory: plugins, commands, MCP servers, hooks. |
| `install-kiro.sh`       | Install OMA skills and steering into `~/.kiro/`. |
| `install-aidlc.sh`      | Clone `awslabs/aidlc-workflows` into `~/.aidlc` and link OMA opt-in extensions. |
| `init-omao.sh`          | Scaffold a `.omao/` workspace inside the current project directory. |
| `validate.py`           | JSON Schema validation for marketplace, plugin, skill, and MCP manifests. |
| `eval-skills.py`        | Static quality evaluator for every SKILL.md and plugin.json. |
| `sync-from-playbook.py` | Regenerate `plugins/*/references/playbook-index.md` from the engineering-playbook repository. |

## Dependencies

| Tool | Used by |
|---|---|
| `bash` 4+     | all `*.sh` scripts |
| `jq`          | `install-claude.sh`, `install-kiro.sh`, `install-aidlc.sh`, optional in `init-omao.sh` |
| `git`         | `install-aidlc.sh`, `sync-from-playbook.py` (for GitHub URL inference) |
| `python3` 3.9+ | all `*.py` scripts |
| `jsonschema` (Python package) | `validate.py` (optional — falls back to required-key checks when missing) |

Install on Ubuntu/Debian:

```bash
sudo apt-get install -y jq git python3
pip install jsonschema
```

Install on macOS (Homebrew):

```bash
brew install jq git python3
pip3 install jsonschema
```

## Usage examples

### Install the marketplace for Claude Code

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops ~/src/oh-my-aidlcops
bash ~/src/oh-my-aidlcops/scripts/install-claude.sh
```

Uses `OMA_OWNER` when present to target a forked owner:

```bash
OMA_OWNER=my-fork bash scripts/install-claude.sh
```

### Install for Kiro

```bash
bash ~/src/oh-my-aidlcops/scripts/install-kiro.sh
```

### Add AIDLC core extensions

```bash
bash ~/src/oh-my-aidlcops/scripts/install-aidlc.sh
# Clones awslabs/aidlc-workflows into ~/.aidlc and links OMA *.opt-in.md files.
```

### Initialize `.omao/` in a user project

```bash
cd ~/work/my-agentic-project
bash ~/src/oh-my-aidlcops/scripts/init-omao.sh
```

Re-initialize after upgrades:

```bash
bash ~/src/oh-my-aidlcops/scripts/init-omao.sh --force
```

### Validate every manifest

```bash
python3 scripts/validate.py
python3 scripts/validate.py --fix-hint    # print corrective hints on failure
```

### Evaluate skill and plugin quality

```bash
python3 scripts/eval-skills.py
python3 scripts/eval-skills.py --strict   # treat WARN as FAIL
python3 scripts/eval-skills.py --plugin agentic-platform --verbose
```

### Regenerate the playbook index

```bash
python3 scripts/sync-from-playbook.py --dry-run
python3 scripts/sync-from-playbook.py --playbook-dir ~/workspace/engineering-playbook
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `OMA_OWNER`                 | `aws-samples`                   | GitHub owner used for the marketplace. Keeps organization transfers low-touch. |
| `CLAUDE_HOME`               | `$HOME/.claude`                 | Override the Claude Code target. |
| `KIRO_HOME`                 | `$HOME/.kiro`                   | Override the Kiro target. |
| `AIDLC_DIR`                 | `$HOME/.aidlc`                  | Target directory for the aidlc-workflows clone. |
| `AIDLC_REPO_URL`            | `https://github.com/awslabs/aidlc-workflows.git` | Override the aidlc-workflows upstream. |
| `ENGINEERING_PLAYBOOK_DIR`  | unset                           | Explicit playbook path for `sync-from-playbook.py`. |

## Exit codes

Shell installers exit `0` on success and non-zero on any failure (missing
dependency, schema mismatch, etc.). Python scripts use:

- `0` — success
- `1` — validation / evaluation failure
- `2` — configuration or runtime error (e.g., missing schema file)

## Safety properties

- No script ever pushes to a remote or mutates upstream repositories.
- No script writes outside of its declared target directories
  (`~/.claude/`, `~/.kiro/`, `~/.aidlc/`, `.omao/`, or `plugins/*/references/`).
- No script replaces a real file with a symlink — it refuses and warns instead.
- `init-omao.sh` refuses to overwrite an existing `.omao/` unless `--force` is
  passed.
- `sync-from-playbook.py` only writes `playbook-index.md`. Hand-authored files
  in `references/` are preserved.
