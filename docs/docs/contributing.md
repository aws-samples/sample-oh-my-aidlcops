---
sidebar_position: 55
title: Contributing
---

# Contributing guide

This project lives under `aws-samples/` and welcomes external
contributions. The [repo root
`CONTRIBUTING.md`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/CONTRIBUTING.md)
covers the legal and PR-process boilerplate. This page adds the
engineering-workflow rules that our CI and review process assume.

## The four working-agreement rules

These four rules are non-negotiable. Every pull request is reviewed
against them before any technical merit discussion begins.

### 1. English-only artifacts

Every byte committed to this repository must be English: source code,
comments, docstrings, commit messages, pull request titles and bodies,
release notes, and `CHANGELOG.md` entries. Chat between reviewers and
contributors may happen in any language, but files and git objects may
not.

**Why.** Reviewers and downstream automation (link checkers, release
note extractors, Dependabot) all assume a single language. A Korean
commit message, even with an English diff, breaks changelog generation
and makes `git log --grep` unreliable. Keeping the rule absolute avoids
hand-wringing about which files are "public" and which are not.

**What to check before committing.** Run `git diff --cached` and read
it top to bottom. If a Korean comment slipped in through an editor's
autocomplete, translate it before pushing.

### 2. No AI attribution in git

Commits, tags, and PR bodies must not carry `Co-Authored-By: Claude`,
`🤖 Generated with Claude Code`, or any equivalent AI attribution.
Trailers list only human authors.

**Why.** Git trailers participate in export control, copyright
attribution, and customer-facing release notes. AI attribution creates
legal ambiguity about authorship and licensing, and it clutters
`git shortlog` output without adding information reviewers can act on.

**What to check before committing.** Some IDE plugins inject trailers
automatically — set `git config --global commit.template ""` if you
find phantom trailers in `git log`. Run
`git log -n 5 --pretty=%b | grep -i claude` after finishing a branch;
strip anything it finds before opening the PR.

### 3. `CLAUDE.md` stays local

`CLAUDE.md` files — whether at the repo root or inside a plugin — are
agent-specific configuration. They belong in `.gitignore` and must not
land in a commit, a PR, or a release artifact.

**Why.** `CLAUDE.md` contains instructions that customise agent
behaviour for individual contributors and can leak internal workflow
details. Tracking it would also freeze everyone's agent prompt at
whatever one contributor committed, which is the opposite of what the
file is for.

**What to check before committing.** `git check-ignore -v CLAUDE.md`
should return a rule hit; if it does not, add `CLAUDE.md` to
`.gitignore` in the same PR. If you see `CLAUDE.md` in
`git status --short`, do not `git add -A` blindly — use explicit paths.

### 4. Commit per unit of work

Every distinct task gets its own commit. Never batch unrelated changes
into a single commit, even when they share a feature branch. A unit of
work is the smallest change that leaves the repository in a reviewable,
reversible state.

**Why.** Reviews are easier when one commit equals one logical change.
Reverts are safer: `git revert <sha>` rolls back exactly one concern
instead of unwinding a shipping release. `git blame` points at the
commit that changed a specific line for a specific reason, not at a
grab bag. And when CI fails mid-merge, you can land the commits that
pass and keep iterating on the one that does not.

**What counts as one unit.**

| Unit | Example |
|------|---------|
| One subsystem fix | Bump a single schema's version enum |
| One schema extension | Add an optional field to `risk.schema.json` |
| One doc update | Write a new Docusaurus page |
| One CI patch | Adjust a single workflow's trigger matrix |
| One refactor | Lift inline strings to module-level constants |
| One test suite | Add pytest coverage for a newly refactored function |

When a branch contains work across several units, make several
commits. Do **not** wait until the end of the branch to stage
everything.

**What to check before committing.** Run `git status --short` and
`git diff --cached --stat`. If the staged paths span more than one
unit, split them:

- Use `git add -p` to stage hunks interactively.
- Use explicit paths (`git add path/to/one/file`) instead of
  `git add -A` or `git add .`.
- If you have already committed a batch, `git reset --soft HEAD~1`
  unstages the mistake without losing the changes so you can split
  cleanly.

**Rule holds under autonomous modes.** The `boulder never stops`
hook, long-running agent loops, and multi-PR workflows all still
honour the rule. Finish a unit, commit it, then start the next one.
Never defer "until the whole plan is done."

## Branch naming

Use a prefix that matches the dominant change type:

| Prefix | When to use |
|--------|-------------|
| `feat/` | User-visible new capability |
| `fix/` | Bug fix (functional or build) |
| `chore/` | Maintenance or dependency hygiene |
| `test/` | Test-only changes |
| `docs/` | Documentation-only changes |
| `refactor/` | Internal change, no user-visible behaviour difference |
| `ci/` | `.github/workflows` changes |

Examples from recent history: `feat/enterprise-ontology-harness-v0.3-v0.5`,
`fix/security-uuid-14`, `feat/auto-release-page`.

## Commit message style

Use imperative English verbs:

- `feat(audit): migrate component-design writer to …` — good
- `feat(audit): migrated component-design writer …` — past tense, bad
- `feat(audit): migration of component-design writer …` — nominalised, bad

Scope is optional but recommended for the larger codebases
(`feat(compile):`, `test(ontology):`, `ci(docs):`). The body should
explain **why**, not just what — the diff already shows what changed.

## Commit splitting in practice

Three recent examples from `main` history illustrate the rule in
action.

### Example 1: v0.3 → v0.5 enterprise rollout

Landed as two commits inside one PR (`feat/enterprise-ontology-harness-v0.3-v0.5`):

- `a4cb99a` — v0.3 foundation (ontology + DSL v2 backbone).
- `9aafc5a` — v0.4 + v0.5 rollout (SLSA, OTEL, OPA, plugin migration,
  enterprise doctor).

The two commits could have been one "enterprise rollout" commit. They
were split because v0.3 is low-risk and release-cuttable on its own;
v0.4/v0.5 build on it but would survive a revert of only the
later commit. Reviewers can read the foundation separately from the
enforcement layer.

### Example 2: CI workflow repair vs unused-imports cleanup

In the same PR that landed the rollout, review feedback surfaced two
follow-up issues. They shipped as two separate commits:

- `b8c4f84` — fix CI workflow script paths. Unrelated pre-existing bug.
- `4c66e7f` — drop unused imports flagged by the code-quality bot.
  Purely cosmetic.

Batching them would have forced a revert of the clean-up to roll back
the CI fix. Splitting kept each concern reversible.

### Example 3: uuid transitive dependency override

PR #4 shipped as a single commit (`eb7388d`):

- `fix(deps): override transitive uuid to 14.0.0 (GHSA-w5hq-g745-h8pq)`

The diff touches only `docs/package.json` and the regenerated
`docs/package-lock.json`, and both files exist to serve the same unit
of work: the security advisory fix. One concern, one commit.

## Running the test suite

```bash
# Python foundation suite (ontology + audit + harness + compile)
python -m pip install -e '.[dev]'
python -m pytest tests/ \
    --ignore=tests/installer \
    --ignore=tests/profile \
    --ignore=tests/hooks \
    --ignore=tests/doctor \
    -q

# Shell tests (bats). Install via brew / apt first.
bats tests/installer
bats tests/profile
bats tests/hooks
bats tests/doctor

# Verify the docs site still builds.
cd docs
npm ci
npm run build
```

## Rebuilding after schema or DSL changes

Any change to `schemas/**/*.schema.json`, `plugins/*/*.oma.yaml`, or
`tools/oma_compile/` should be followed by:

```bash
oma compile --all            # regenerate .mcp.json and kiro-agents/*.agent.json
oma doctor --enterprise      # run the 8 enterprise-readiness probes
```

These two commands are the integration test for cross-file coherence.
If they fail in a PR, do not merge.

## Questions

Open a GitHub issue with the `question` label. The maintainers rotate
through unanswered issues weekly.
