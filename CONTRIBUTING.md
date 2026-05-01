# Contributing Guidelines

Thank you for your interest in contributing to this project. Whether it is
a bug report, new feature, correction, or additional documentation, we
value feedback and contributions from the community.

Please read this document before submitting any issue or pull request.

## Working agreement

Four rules govern every change that lands on `main`. They override any
conflicting local convention and apply in both manual and automated
execution modes.

1. **English-only artifacts.** Every committed byte must be in English —
   source code, comments, docstrings, commit messages, PR titles, PR
   bodies, release notes, and `CHANGELOG.md` entries. Chat with reviewers
   may happen in any language; files and git objects may not.
2. **No AI attribution in git.** Do not add `Co-Authored-By: Claude`,
   `🤖 Generated with Claude Code`, or any equivalent AI attribution to
   commits, tags, or PR bodies. Git trailers list only human authors. If
   a commit template injects such lines, strip them before committing.
3. **`CLAUDE.md` stays local.** `CLAUDE.md` files (project root or
   plugin-level) are agent-specific configuration and must remain in
   `.gitignore`. Never `git add` them, and never revert the ignore rule.
4. **Commit per unit of work.** Every distinct task gets its own commit.
   Do not batch unrelated changes into a single commit, even when they
   share a feature branch. A unit of work is the smallest change that
   leaves the repository in a reviewable, reversible state: one
   subsystem fix, one schema extension, one doc update, one CI patch.
   Before `git commit`, inspect `git status` and `git diff --stat` and
   confirm every staged path belongs to the same logical task. If they
   do not, split with `git add -p` or by staging individual files. This
   rule applies under autonomous and long-running execution modes as
   well — finish a unit, commit, then start the next unit. Do not defer
   commits "until the whole plan is done."

See [`docs/docs/contributing.md`](./docs/docs/contributing.md) for the
long-form rationale, branch naming conventions, and worked examples.

## Branch naming and commit messages

Use a prefix that matches the dominant change type: `feat/`, `fix/`,
`chore/`, `test/`, `docs/`, `refactor/`, or `ci/`. Commit messages use
imperative English ("add X", "fix Y", not "added"/"fixes"). The body
explains *why*, not what — the diff already shows what changed.

## Reporting bugs and feature requests

We welcome you to use the GitHub issue tracker to report bugs or suggest
features.

When filing an issue, please check existing open and recently closed
issues to make sure someone else has not already reported it. Include as
much information as you can:

* A reproducible test case or series of steps.
* The version of our code being used.
* Any modifications you made relevant to the bug.
* Anything unusual about your environment or deployment.

## Contributing via pull requests

Before sending us a pull request, please ensure that:

1. You are working against the latest source on the `main` branch.
2. You checked existing open and recently merged pull requests to make
   sure someone else has not already addressed the problem.
3. You opened an issue to discuss any significant work — we would hate
   for your time to be wasted.

To send us a pull request:

1. Fork the repository.
2. Create a feature branch using one of the prefixes listed above.
3. Modify the source; please focus on the specific change you are
   contributing. If you also reformat all the code, it will be hard for
   us to focus on your change.
4. Ensure local tests pass (`pytest tests/` for the foundation suite,
   `bats tests/installer tests/profile tests/hooks tests/doctor` for
   shell tests).
5. Commit to your fork using clear imperative English commit messages.
   One commit per unit of work.
6. Send us a pull request, answering any default questions in the pull
   request interface.
7. Pay attention to any automated CI failures reported in the pull
   request, and stay involved in the conversation.

GitHub documents the mechanics of
[forking a repository](https://help.github.com/articles/fork-a-repo/) and
[creating a pull request](https://help.github.com/articles/creating-a-pull-request/).

## Finding contributions to work on

Looking at existing issues is a great way to find something to work on.
This project uses the default GitHub issue labels
(enhancement/bug/duplicate/help wanted/invalid/question/wontfix); the
`help wanted` label is a good starting point.

## Code of Conduct

This project has adopted the
[Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the
[Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or
contact opensource-codeofconduct@amazon.com with any additional
questions or comments.

## Security issue notifications

If you discover a potential security issue in this project we ask that
you notify AWS/Amazon Security via our
[vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/).
Please do **not** create a public GitHub issue.

## Licensing

See the [LICENSE](LICENSE) file for this project's licensing. We will
ask you to confirm the licensing of your contribution.
