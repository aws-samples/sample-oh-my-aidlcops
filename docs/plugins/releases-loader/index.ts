/**
 * releases-loader — Docusaurus plugin that fetches GitHub Releases at
 * build time and exposes them to the Releases page as a static data file.
 *
 * The plugin runs unauthenticated against the public API. GitHub Actions
 * may supply a token via GITHUB_TOKEN / OMA_RELEASES_TOKEN to raise the
 * anonymous rate limit from 60 req/h to 5000 req/h on the official
 * runners.
 *
 * If the API is unreachable at build time (offline dev, rate limit), the
 * plugin emits an empty list and logs a warning rather than failing the
 * build — the site keeps working with a "no releases yet" notice.
 */

import type { LoadContext, Plugin } from '@docusaurus/types';

export interface ReleaseAsset {
  name: string;
  browser_download_url: string;
  size: number;
}

export interface ReleaseRecord {
  tag_name: string;
  name: string;
  published_at: string | null;
  html_url: string;
  prerelease: boolean;
  draft: boolean;
  body: string;
  assets: ReleaseAsset[];
}

interface PluginOptions {
  repo: string;     // "owner/name"
  perPage?: number; // default 20
}

const API_BASE = 'https://api.github.com';

async function fetchReleases(repo: string, perPage: number): Promise<ReleaseRecord[]> {
  const token = process.env.GITHUB_TOKEN || process.env.OMA_RELEASES_TOKEN;
  const headers: Record<string, string> = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'oma-docs-release-loader',
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const url = `${API_BASE}/repos/${repo}/releases?per_page=${perPage}`;
  const res = await fetch(url, { headers });
  if (!res.ok) {
    throw new Error(
      `GitHub Releases API returned ${res.status} ${res.statusText} for ${repo}`,
    );
  }
  const data = (await res.json()) as Array<Record<string, unknown>>;
  return data.map((r) => ({
    tag_name: String(r.tag_name ?? ''),
    name: String(r.name ?? r.tag_name ?? ''),
    published_at: (r.published_at as string | null) ?? null,
    html_url: String(r.html_url ?? ''),
    prerelease: Boolean(r.prerelease),
    draft: Boolean(r.draft),
    body: String(r.body ?? ''),
    assets: Array.isArray(r.assets)
      ? (r.assets as Array<Record<string, unknown>>).map((a) => ({
          name: String(a.name ?? ''),
          browser_download_url: String(a.browser_download_url ?? ''),
          size: Number(a.size ?? 0),
        }))
      : [],
  }));
}

export default function releasesLoaderPlugin(
  _context: LoadContext,
  options: PluginOptions,
): Plugin<{ releases: ReleaseRecord[]; fetchedAt: string; source: string }> {
  const { repo, perPage = 20 } = options;
  if (!repo || !/^[^/]+\/[^/]+$/.test(repo)) {
    throw new Error(`releases-loader: invalid repo option ${JSON.stringify(repo)}`);
  }

  return {
    name: 'releases-loader',

    async loadContent() {
      const fetchedAt = new Date().toISOString();
      try {
        const releases = await fetchReleases(repo, perPage);
        // Skip drafts; consumer UI shows pre-releases with a badge.
        const visible = releases.filter((r) => !r.draft);
        return { releases: visible, fetchedAt, source: repo };
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        // eslint-disable-next-line no-console
        console.warn(
          `[releases-loader] failed to fetch ${repo} releases (${msg}); ` +
          `building with an empty list`,
        );
        return { releases: [], fetchedAt, source: repo };
      }
    },

    async contentLoaded({ content, actions }) {
      const { createData, setGlobalData } = actions;
      // createData writes a static JSON file available to pages via the
      // standard static-site data channel; setGlobalData exposes the same
      // payload to any component via useGlobalData().
      await createData('releases.json', JSON.stringify(content, null, 2));
      setGlobalData(content);
    },
  };
}
