/**
 * /releases — static page rendered from the snapshot that
 * plugins/releases-loader fetches at build time.
 *
 * Re-build the site to refresh the list. docs-build.yml triggers on
 * `release.published` so a new GitHub Release automatically rebuilds
 * and redeploys the Pages site.
 */

import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import { usePluginData } from '@docusaurus/useGlobalData';
import type { ReleaseRecord } from '../../plugins/releases-loader';

interface LoaderData {
  releases: ReleaseRecord[];
  fetchedAt: string;
  source: string;
}

function formatBytes(bytes: number): string {
  if (!bytes) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let n = bytes;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i += 1;
  }
  return `${n.toFixed(n < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
}

function formatDate(iso: string | null): string {
  if (!iso) return '';
  return new Date(iso).toISOString().slice(0, 10);
}

export default function ReleasesPage(): React.ReactElement {
  const data = usePluginData('releases-loader') as LoaderData | undefined;
  const releases = data?.releases ?? [];
  const fetchedAt = data?.fetchedAt ?? '';
  const source = data?.source ?? '';

  return (
    <Layout
      title="Releases"
      description="OMA tech-preview releases, published when a v* tag ships."
    >
      <main className="container margin-vert--lg">
        <h1>Releases</h1>
        <p>
          Tech-preview builds of <code>oh-my-aidlcops</code>. Each release ships
          a reproducible tarball plus a <code>.sha256</code> checksum. See the
          individual release pages on GitHub for the full changelog and signed
          assets.
        </p>

        <p style={{ color: 'var(--ifm-color-emphasis-600)', fontSize: '0.9rem' }}>
          Data source:{' '}
          <Link to={`https://github.com/${source}/releases`}>
            github.com/{source}/releases
          </Link>
          {fetchedAt ? (
            <>
              {' · '}snapshot built {formatDate(fetchedAt)}
            </>
          ) : null}
          {' · '}
          <Link to="https://github.com/aws-samples/sample-oh-my-aidlcops/subscription">
            watch for new releases
          </Link>
        </p>

        {releases.length === 0 ? (
          <div
            className="alert alert--info"
            role="alert"
            style={{ marginTop: '1.5rem' }}
          >
            No releases captured in this build. Either the API was unreachable
            at build time, or no tag has been pushed yet. Check the source link
            above for the live list.
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            {releases.map((r) => (
              <article
                key={r.tag_name}
                style={{
                  border: '1px solid var(--ifm-color-emphasis-300)',
                  borderRadius: '0.5rem',
                  padding: '1rem 1.25rem',
                  background: 'var(--ifm-background-surface-color)',
                }}
              >
                <header
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'baseline',
                    gap: '0.75rem',
                    flexWrap: 'wrap',
                  }}
                >
                  <h2 style={{ marginBottom: 0 }}>
                    <Link to={r.html_url}>{r.name || r.tag_name}</Link>
                    {r.prerelease ? (
                      <span
                        className="badge badge--warning"
                        style={{ marginLeft: '0.75rem', verticalAlign: 'middle' }}
                      >
                        pre-release
                      </span>
                    ) : null}
                  </h2>
                  <span style={{ color: 'var(--ifm-color-emphasis-700)' }}>
                    {formatDate(r.published_at)} · {r.tag_name}
                  </span>
                </header>

                {r.body ? (
                  <details style={{ marginTop: '0.75rem' }}>
                    <summary style={{ cursor: 'pointer' }}>Release notes</summary>
                    <pre
                      style={{
                        whiteSpace: 'pre-wrap',
                        background: 'var(--ifm-color-emphasis-100)',
                        padding: '0.75rem 1rem',
                        borderRadius: '0.25rem',
                        marginTop: '0.5rem',
                      }}
                    >
                      {r.body}
                    </pre>
                  </details>
                ) : null}

                {r.assets.length > 0 ? (
                  <div style={{ marginTop: '0.75rem' }}>
                    <strong>Assets</strong>
                    <ul>
                      {r.assets.map((a) => (
                        <li key={a.browser_download_url}>
                          <Link to={a.browser_download_url}>{a.name}</Link>
                          {a.size ? (
                            <span
                              style={{
                                color: 'var(--ifm-color-emphasis-600)',
                                marginLeft: '0.5rem',
                              }}
                            >
                              ({formatBytes(a.size)})
                            </span>
                          ) : null}
                        </li>
                      ))}
                    </ul>
                  </div>
                ) : null}
              </article>
            ))}
          </div>
        )}
      </main>
    </Layout>
  );
}
