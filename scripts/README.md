# oh-my-aidlcops — scripts/

Operational scripts for installing, initializing, validating, and syncing the
oh-my-aidlcops (OMA) plugin marketplace.

All scripts are idempotent. Re-running them is always safe and will only apply
the missing changes. Every script supports `--help`.

Starting in `v0.2.0-preview.1` the preferred entry point is the `oma` CLI
(`bin/oma`). The scripts below are still the implementation backbone and can
be invoked directly for advanced or CI use cases.

## Layout

```
scripts/
├── install/                   — harness-specific installers
│   ├── claude.sh
│   ├── kiro.sh
│   └── aidlc-extensions.sh
├── oma/                       — oma CLI subcommands
│   ├── setup.sh
│   ├── doctor.sh
│   ├── compile.sh
│   ├── status.sh
│   ├── upgrade.sh
│   ├── uninstall.sh
│   └── _seed.sh
├── lib/                       — shared shell libraries
│   ├── log.sh
│   ├── profile.sh
│   └── jq-ontology.sh
├── dev/                       — developer / CI utilities
│   ├── eval-skills.py
│   ├── validate.py
│   ├── validate_strict.py
│   ├── sync-from-playbook.py
│   └── make-tarball.sh
├── init-omao.sh               — scaffold project-local .omao/
├── install-claude.sh          — backwards-compat shim → install/claude.sh
├── install-kiro.sh            — backwards-compat shim → install/kiro.sh
└── install-aidlc.sh           — backwards-compat shim → install/aidlc-extensions.sh
```

## Scripts

| Script | Purpose |
|---|---|
| `install/claude.sh`            | Install OMA into `~/.claude/`: plugins, commands, MCP servers, hooks. |
| `install/kiro.sh`              | Install OMA skills and steering into `~/.kiro/`. |
| `install/aidlc-extensions.sh`  | Clone `awslabs/aidlc-workflows` into `~/.aidlc` and link OMA opt-in extensions. |
| `oma/setup.sh`                 | Profile wizard + install + seed ontology + compile + doctor. |
| `oma/doctor.sh`                | 12-probe environment check with pretty + JSON output. |
| `oma/compile.sh`               | Wrapper for `python -m tools.oma_compile`. |
| `oma/status.sh`                | Print the current `.omao/profile.yaml` summary. |
| `oma/upgrade.sh`               | `git pull` + `setup --migrate` (clone installs only). |
| `oma/uninstall.sh`             | Reverse symlinks and remove OMA hooks from `~/.claude/settings.json`. |
| `init-omao.sh`                 | Scaffold a `.omao/` workspace inside the current project directory. |
| `dev/validate.py`              | JSON Schema validation for marketplace, plugin, skill, and MCP manifests. |
| `dev/validate_strict.py`       | Same, using the `jsonschema` library with stricter messages. |
| `dev/eval-skills.py`           | Static quality evaluator for every SKILL.md and plugin.json. |
| `dev/sync-from-playbook.py`    | Regenerate `plugins/*/references/playbook-index.md` from the engineering-playbook repository. |
| `dev/make-tarball.sh`          | Produce a release tarball under `dist/`. |

## Dependencies

| Tool | Used by |
|---|---|
| `bash` 4+       | all `*.sh` scripts |
| `jq`            | every `install/*.sh`, every `oma/*.sh`, optional in `init-omao.sh` |
| `git`           | `install/aidlc-extensions.sh`, `dev/sync-from-playbook.py` |
| `python3` 3.9+  | `oma/compile.sh`, every `dev/*.py` |
| `pyyaml`        | profile + DSL validation (falls back gracefully when missing) |
| `jsonschema`    | `dev/validate.py` (optional — falls back to required-key checks) |

Install on Ubuntu/Debian:

```bash
sudo apt-get install -y jq git python3 python3-pip
pip install jsonschema pyyaml
```

Install on macOS (Homebrew):

```bash
brew install jq git python3
pip3 install jsonschema pyyaml
```

## Usage examples

### Preferred: the `oma` CLI

```bash
# In your project directory
oma setup        # wizard + install + seed + compile + doctor
oma doctor       # 12 probes
oma compile      # regenerate .mcp.json / agent.json from *.oma.yaml sources
oma status       # show the active profile
```

If `oma` is not on your PATH, run `bin/oma` directly or add `~/.local/bin` to
your PATH (the remote installer prints the export line to add).

### Direct installer invocation

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops ~/src/oh-my-aidlcops
bash ~/src/oh-my-aidlcops/scripts/install/claude.sh
```

Use `OMA_OWNER` when targeting a fork:

```bash
OMA_OWNER=my-fork bash scripts/install/claude.sh
```

Kiro:

```bash
bash ~/src/oh-my-aidlcops/scripts/install/kiro.sh
```

AIDLC core extensions:

```bash
bash ~/src/oh-my-aidlcops/scripts/install/aidlc-extensions.sh
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
python3 scripts/dev/validate.py
python3 scripts/dev/validate.py --fix-hint    # print corrective hints on failure
python3 scripts/dev/validate_strict.py        # stricter, uses jsonschema library
```

### Evaluate skill and plugin quality

```bash
python3 scripts/dev/eval-skills.py
python3 scripts/dev/eval-skills.py --strict
python3 scripts/dev/eval-skills.py --plugin ai-infra --verbose
```

### Regenerate the playbook index

```bash
python3 scripts/dev/sync-from-playbook.py --dry-run
python3 scripts/dev/sync-from-playbook.py --playbook-dir ~/workspace/engineering-playbook
```

### Build a release tarball

```bash
bash scripts/dev/make-tarball.sh
# Writes dist/oh-my-aidlcops-<version>.tar.gz and .sha256.
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `OMA_OWNER`                 | `aws-samples`                   | GitHub owner used for the marketplace. |
| `CLAUDE_HOME`               | `$HOME/.claude`                 | Override the Claude Code target. |
| `KIRO_HOME`                 | `$HOME/.kiro`                   | Override the Kiro target. |
| `AIDLC_DIR`                 | `$HOME/.aidlc`                  | Target directory for the aidlc-workflows clone. |
| `AIDLC_REPO_URL`            | `https://github.com/awslabs/aidlc-workflows.git` | Override the aidlc-workflows upstream. |
| `ENGINEERING_PLAYBOOK_DIR`  | unset                           | Explicit playbook path for `sync-from-playbook.py`. |
| `OMA_REPO_ROOT`             | auto                            | Override the root directory the `oma` CLI resolves. |
| `OMA_NON_INTERACTIVE`       | `0`                             | When `1`, `oma setup` reads answers from env vars only. |
| `OMA_DISABLE_ONTOLOGY`      | `0`                             | When `1`, hooks stop reading `.omao/ontology/`. |

## Backwards-compat shims

The root-level `install-claude.sh`, `install-kiro.sh`, and `install-aidlc.sh`
are shims that `exec` into `install/*.sh`. They are kept so that existing
documentation, muscle memory, and `curl` URLs from earlier releases keep
working for at least one minor release cycle.

## Exit codes

Shell installers exit `0` on success and non-zero on any failure (missing
dependency, schema mismatch, etc.). Python scripts use:

- `0` — success
- `1` — validation / evaluation failure
- `2` — configuration or runtime error (e.g., missing schema file)

## Safety properties

- No script ever pushes to a remote or mutates upstream repositories.
- No script writes outside of its declared target directories
  (`~/.claude/`, `~/.kiro/`, `~/.aidlc/`, `.omao/`, `plugins/*/references/`,
  or `dist/`).
- No script replaces a real file with a symlink — it refuses and warns instead.
- `init-omao.sh` refuses to overwrite an existing `.omao/` unless `--force` is
  passed.
- `sync-from-playbook.py` only writes `playbook-index.md`. Hand-authored files
  in `references/` are preserved.
