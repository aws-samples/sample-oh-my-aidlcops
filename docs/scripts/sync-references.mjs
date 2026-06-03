#!/usr/bin/env node
// docs/scripts/sync-references.mjs — copy REFERENCES.md from repo root
// into docs/docs/references.md with a Docusaurus frontmatter prepended
// and a mirror banner. Runs automatically via `npm run prebuild` and
// `npm run prestart` so the Pages site is always in sync with the
// canonical reference catalogue at the repo root.
//
// Source of truth stays the repo-root REFERENCES.md. Do NOT edit
// docs/docs/references.md by hand — it is overwritten on every build.

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const repoRoot = resolve(__dirname, '..', '..');
const sourcePath = resolve(repoRoot, 'REFERENCES.md');
// English is the default locale, so the source lives under docs/docs.
// REFERENCES.md is an English-only catalogue, but the ko locale still
// needs a copy at the same relative path so that ko docs linking to
// `./references.md` / `../references.md` resolve (Docusaurus resolves
// relative .md links within the active locale's tree). The ko copy is
// intentionally the same English content.
const targetPaths = [
  resolve(__dirname, '..', 'docs', 'references.md'),
  resolve(
    __dirname,
    '..',
    'i18n',
    'ko',
    'docusaurus-plugin-content-docs',
    'current',
    'references.md',
  ),
];

const FRONTMATTER = `---
sidebar_position: 57
title: References
description: External specs, upstream repos, frameworks, and runtime tools OMA cites. Mirror of the repo-root REFERENCES.md.
---

:::info Mirror of repo-root REFERENCES.md
This page is auto-synced from [\`REFERENCES.md\`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/REFERENCES.md)
at the repository root on every Docusaurus build. Edit the root file,
not this copy — \`docs/scripts/sync-references.mjs\` overwrites this
file during \`npm run build\` / \`npm run start\`.
:::

`;

// Rewrite root-relative markdown links (./NOTICE, ./LICENSE, etc.) so
// the Docusaurus build does not warn about broken internal links when
// the rendered page lives under /docs/references instead of the repo
// root. The GitHub blob URL keeps the link working both on the Pages
// site and when someone views the Markdown source directly.
const LINK_REWRITES = [
  { pattern: /\]\(\.\/NOTICE\)/g, replacement: '](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE)' },
  { pattern: /\]\(\.\/LICENSE\)/g, replacement: '](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/LICENSE)' },
  { pattern: /\]\(\.\/CHANGELOG\.md\)/g, replacement: '](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/CHANGELOG.md)' },
  { pattern: /\]\(\.\/CONTRIBUTING\.md\)/g, replacement: '](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/CONTRIBUTING.md)' },
];

try {
  const source = await readFile(sourcePath, 'utf8');
  let rewritten = source;
  for (const { pattern, replacement } of LINK_REWRITES) {
    rewritten = rewritten.replace(pattern, replacement);
  }
  const lineCount = rewritten.split('\n').length;
  for (const targetPath of targetPaths) {
    await mkdir(dirname(targetPath), { recursive: true });
    await writeFile(targetPath, FRONTMATTER + rewritten, 'utf8');
    // Echo a short line so the build log shows the sync happened.
    console.log(
      `[sync-references] copied ${sourcePath.replace(repoRoot + '/', '')} ` +
        `-> ${targetPath.replace(repoRoot + '/', '')} (${lineCount} lines)`,
    );
  }
} catch (err) {
  console.error(`[sync-references] failed: ${err.message}`);
  process.exit(1);
}
