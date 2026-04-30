import React from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

type Capability = {
  title: string;
  body: string;
  icon: string;
  variant: 'wide' | 'accent' | 'quiet' | 'terminal';
  bullets?: string[];
  code?: string[];
};

const CAPABILITIES: Capability[] = [
  {
    title: 'Autopilot deploys',
    body:
      'autopilot-deploy runs canary 1% → 10% → 50% → 100% with SLO-gated circuit breakers. Each stage waits for continuous-eval before promotion; regression trips auto-rollback.',
    icon: 'rocket',
    variant: 'wide',
    bullets: ['Argo Rollouts / Flagger', 'Prometheus SLO gates', 'Human approval at 100%'],
  },
  {
    title: 'Self-healing',
    body:
      'incident-response classifies SEV1–4, pulls the matching runbook, issues diagnostic MCP queries, and drafts a remediation script for approval. SEV1 pages on-call; it never acts.',
    icon: 'shield',
    variant: 'accent',
  },
  {
    title: 'Cost governance',
    body:
      'cost-governance attributes spend per agent, vetoes deploys that would breach the monthly ceiling, and drafts Opus → Sonnet → Haiku downgrade PRs. budget.yaml runs in a simpleeval sandbox — no Python eval, no RCE vector.',
    icon: 'coin',
    variant: 'quiet',
  },
  {
    title: 'CLI first. Always.',
    body:
      'Every skill is reachable as a slash command in Claude Code or a direct skill call in Kiro. The full state lives under .omao/ and is portable between harnesses.',
    icon: 'terminal',
    variant: 'terminal',
    code: [
      '> /plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops',
      '> /plugin install agentic-platform agenticops modernization',
      '> /oma:platform-bootstrap',
      '  [1/5] Gather Context  …  ok',
      '  [2/5] Pre-flight      …  ok',
    ],
  },
];

const PLUGINS = [
  {
    name: 'agentic-platform',
    tagline: 'Build the platform',
    body:
      'EKS + vLLM + Inference Gateway + Langfuse. Skills for bootstrap, GPU planning, routing, observability, and guardrails. MCP servers pinned to exact PyPI versions — no @latest.',
  },
  {
    name: 'agenticops',
    tagline: 'Operate with agents',
    body:
      'self-improving-loop, autopilot-deploy, incident-response, continuous-eval, cost-governance, audit-trail. Humans approve, agents execute.',
  },
  {
    name: 'aidlc-inception',
    tagline: 'Phase 1 — intent',
    body:
      'structured-intake, requirements-analysis, user-stories, workflow-planning. Produces the artifacts Construction consumes as a single source of truth.',
  },
  {
    name: 'aidlc-construction',
    tagline: 'Phase 2 — build',
    body:
      'component-design, code-generation, test-strategy, risk-discovery, quality-gates. LLM calls are mocked in tests; golden evals gate every merge.',
  },
  {
    name: 'modernization',
    tagline: 'Legacy → AWS',
    body:
      'workload-assessment, modernization-strategy (6R), to-be-architecture, containerization, cutover-planning. Uses Kiro-style stage-gated progression.',
  },
];

const INTEGRATIONS = [
  {
    title: 'Claude Code plugin',
    icon: 'plug',
    body:
      'Ship as a native Claude Code marketplace entry. Slash commands, keyword triggers, and the AWS hosted MCP layer work out of the box.',
  },
  {
    title: 'Kiro skills',
    icon: 'spark',
    body:
      'install/kiro.sh symlinks every skill into ~/.kiro/skills/ and wires kiro-agents profiles with pinned MCP server versions.',
  },
  {
    title: 'Shared .omao state',
    icon: 'layers',
    body:
      'Tier-0 mode, project memory, and audit logs live in .omao/. Both harnesses read and write the same directory — switch without losing context.',
  },
];

const Icon = ({ name }: { name: string }) => {
  switch (name) {
    case 'rocket':
      return (
        <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z" />
          <path d="M12 15l-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z" />
          <path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0" />
          <path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5" />
        </svg>
      );
    case 'shield':
      return (
        <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M12 2l8 4v6c0 5-3.5 9-8 10-4.5-1-8-5-8-10V6z" />
          <path d="M9 12l2 2 4-4" />
        </svg>
      );
    case 'coin':
      return (
        <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="9" />
          <path d="M15 9.5A3 3 0 0 0 12 8c-1.66 0-3 1-3 2s1 1.6 3 2 3 .9 3 2-1.34 2-3 2a3 3 0 0 1-3-1.5" />
          <path d="M12 6v2M12 16v2" />
        </svg>
      );
    case 'terminal':
      return (
        <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <rect x="3" y="4" width="18" height="16" rx="2" />
          <path d="M7 9l3 3-3 3M13 15h4" />
        </svg>
      );
    case 'plug':
      return (
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M9 2v4M15 2v4" />
          <path d="M7 6h10v5a5 5 0 1 1-10 0z" />
          <path d="M12 16v6" />
        </svg>
      );
    case 'spark':
      return (
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M12 2v6M12 16v6M2 12h6M16 12h6" />
          <path d="M5 5l3.5 3.5M15.5 15.5L19 19M19 5l-3.5 3.5M8.5 15.5L5 19" />
        </svg>
      );
    case 'layers':
      return (
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M12 3l9 5-9 5-9-5 9-5z" />
          <path d="M3 13l9 5 9-5" />
          <path d="M3 18l9 5 9-5" />
        </svg>
      );
    default:
      return null;
  }
};

export default function HomeLanding(): React.ReactElement {
  return (
    <div className={styles.wrapper}>
      {/* HERO */}
      <section className={styles.hero}>
        <div className={styles.heroGrid}>
          <div className={styles.heroCopy}>
            <div className={styles.eyebrow}>
              <span className={styles.eyebrowDot} aria-hidden="true" />
              aws-samples · AgenticOps
            </div>
            <div className={styles.previewBadge} role="note">
              <span className={styles.previewBadgeLabel}>Tech Preview</span>
              <span className={styles.previewBadgeText}>
                v0.2.0-preview.1 — API may change before GA. See the{' '}
                <Link to={useBaseUrl('/docs/support-policy')}>support policy</Link>.
              </span>
            </div>
            <h1 className={styles.heroTitle}>
              Autonomous operations<br />
              for the <span className={styles.accent}>AWS&nbsp;AIDLC</span> loop.
            </h1>
            <p className={styles.heroLede}>
              Extend Claude Code and Kiro with AgenticOps plugins and skills. OMA closes the
              loop between design, construction, and operations — humans approve at checkpoints,
              agents execute everything in between.
            </p>
            <div className={styles.heroCtaRow}>
              <Link className={styles.ctaPrimary} to={useBaseUrl('/docs/getting-started')}>
                Get started
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M5 12h14M13 6l6 6-6 6" />
                </svg>
              </Link>
              <a
                className={styles.ctaSecondary}
                href="https://github.com/aws-samples/sample-oh-my-aidlcops"
                target="_blank"
                rel="noreferrer"
              >
                View on GitHub
              </a>
            </div>
            <dl className={styles.heroStats}>
              <div>
                <dt>Plugins</dt>
                <dd>5</dd>
              </div>
              <div>
                <dt>Tier-0 workflows</dt>
                <dd>8</dd>
              </div>
              <div>
                <dt>AWS MCP servers</dt>
                <dd>11 pinned</dd>
              </div>
            </dl>
          </div>

          <div className={styles.heroMock}>
            <div className={styles.heroMockFrame}>
              <div className={styles.mockDots} aria-hidden="true">
                <span />
                <span />
                <span />
              </div>
              <div className={styles.mockBody}>
                <p>
                  <span className={styles.muted}>$</span>{' '}
                  <span className={styles.mono}>claude --use-plugin oma</span>
                </p>
                <p className={styles.muted}>Initializing OMA AgenticOps plugin…</p>
                <p className={styles.mutedLight}>✔ Identity context synced with AWS</p>
                <p className={styles.mutedLight}>
                  ✔ MCP servers pinned (eks 0.1.28, cloudwatch 0.0.25, …)
                </p>
                <p className={styles.mutedLight}>
                  ✔ Skills: autopilot-deploy, self-improving-loop, cost-governance
                </p>
                <p className={styles.prompt}>
                  Claude &gt; <em>"How can I help you today?"</em>
                </p>
                <p>
                  <span className={styles.muted}>$</span>{' '}
                  <span className={styles.strong}>deploy rag-qa-agent:v2.3.1 to staging</span>
                </p>
                <div className={styles.mockCallout}>
                  OMA · intercepting · analyzing budget, SLOs, and eval baselines before rollout…
                </div>
              </div>
            </div>
            <span className={styles.mockGlow1} aria-hidden="true" />
            <span className={styles.mockGlow2} aria-hidden="true" />
          </div>
        </div>
      </section>

      {/* INTEGRATION */}
      <section className={styles.integration}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>Seamless integration</p>
          <h2 className={styles.sectionTitle}>
            OMA isn't a separate tool; it's the operational brain inside your favorite AI coding agents.
          </h2>
        </header>
        <div className={styles.integrationGrid}>
          {INTEGRATIONS.map((item) => (
            <article key={item.title} className={styles.integrationCard}>
              <div className={styles.integrationIcon}>
                <Icon name={item.icon} />
              </div>
              <h3>{item.title}</h3>
              <p>{item.body}</p>
            </article>
          ))}
        </div>
      </section>

      {/* AIDLC LOOP */}
      <section className={styles.loopSection}>
        <div className={styles.loopCard}>
          <div className={styles.loopCopy}>
            <h2 className={styles.sectionTitleTight}>The AI Development Lifecycle (AIDLC) loop</h2>
            <ol className={styles.loopList}>
              <li>
                <span className={styles.loopStep}>1</span>
                <div>
                  <h4>Inception</h4>
                  <p>
                    Structured intake, requirements, user stories, and workflow planning. Every
                    artifact is the contract Construction will honor.
                  </p>
                </div>
              </li>
              <li>
                <span className={styles.loopStep}>2</span>
                <div>
                  <h4>Construction</h4>
                  <p>
                    Component design, code generation with human-approved gates, risk discovery
                    across 12 categories, and TDD for agentic systems.
                  </p>
                </div>
              </li>
              <li>
                <span className={styles.loopStep}>3</span>
                <div>
                  <h4>Operations</h4>
                  <p>
                    Autopilot deploys, continuous eval, incident response, cost governance, and
                    the self-improving loop that feeds learnings back into Construction.
                  </p>
                </div>
              </li>
            </ol>
          </div>
          <div className={styles.loopVisual} aria-hidden="true">
            <svg viewBox="0 0 360 360" role="presentation">
              <defs>
                <linearGradient id="loopGrad" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="var(--oma-primary)" />
                  <stop offset="100%" stopColor="var(--oma-primary-container)" />
                </linearGradient>
              </defs>
              <rect x="30" y="30" width="300" height="300" rx="56" fill="none" stroke="var(--oma-surface-container-high)" strokeWidth="14" />
              <path
                d="M30 180 V330 H330 V180"
                fill="none"
                stroke="url(#loopGrad)"
                strokeWidth="14"
                strokeLinecap="round"
              />
              <g>
                <circle cx="180" cy="30" r="22" fill="var(--oma-surface-container-lowest)" stroke="var(--oma-outline-variant)" />
                <text x="180" y="36" textAnchor="middle" fontSize="14" fontWeight="600" fill="var(--oma-primary)">1</text>
              </g>
              <g>
                <circle cx="330" cy="180" r="22" fill="var(--oma-surface-container-lowest)" stroke="var(--oma-outline-variant)" />
                <text x="330" y="186" textAnchor="middle" fontSize="14" fontWeight="600" fill="var(--oma-primary)">2</text>
              </g>
              <g>
                <circle cx="180" cy="330" r="22" fill="var(--oma-surface-container-lowest)" stroke="var(--oma-outline-variant)" />
                <text x="180" y="336" textAnchor="middle" fontSize="14" fontWeight="600" fill="var(--oma-primary)">3</text>
              </g>
              <text x="180" y="176" textAnchor="middle" fontSize="13" letterSpacing="3" fontWeight="700" fill="var(--oma-on-surface-variant)">AUTONOMOUS</text>
              <text x="180" y="198" textAnchor="middle" fontSize="10" letterSpacing="2" fill="var(--oma-outline)">HUMANS APPROVE · AGENTS EXECUTE</text>
            </svg>
          </div>
        </div>
      </section>

      {/* CAPABILITIES */}
      <section className={styles.capabilities}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>AgenticOps capabilities</p>
          <h2 className={styles.sectionTitle}>Purpose-built for the autonomous era.</h2>
        </header>
        <div className={styles.bento}>
          {CAPABILITIES.map((cap) => (
            <article
              key={cap.title}
              className={`${styles.bentoCard} ${styles[`variant_${cap.variant}`]}`}
            >
              <div className={styles.bentoIcon}>
                <Icon name={cap.icon} />
              </div>
              <h3>{cap.title}</h3>
              <p>{cap.body}</p>
              {cap.bullets && (
                <ul className={styles.bentoBullets}>
                  {cap.bullets.map((b) => (
                    <li key={b}>
                      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                        <path d="M20 6L9 17l-5-5" />
                      </svg>
                      {b}
                    </li>
                  ))}
                </ul>
              )}
              {cap.code && (
                <pre className={styles.bentoCode}>
                  {cap.code.map((line, i) => (
                    <code key={i}>{line}</code>
                  ))}
                </pre>
              )}
            </article>
          ))}
        </div>
      </section>

      {/* PLUGINS */}
      <section className={styles.plugins}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>Five plugins</p>
          <h2 className={styles.sectionTitle}>
            Install only what you need — or all of them with one marketplace command.
          </h2>
        </header>
        <div className={styles.pluginGrid}>
          {PLUGINS.map((p) => (
            <article key={p.name} className={styles.pluginCard}>
              <div className={styles.pluginHeading}>
                <span className={styles.pluginName}>{p.name}</span>
                <span className={styles.pluginTagline}>{p.tagline}</span>
              </div>
              <p>{p.body}</p>
            </article>
          ))}
        </div>
      </section>

      {/* SECURITY */}
      <section className={styles.security}>
        <div className={styles.securityInner}>
          <p className={styles.kicker}>Secure by default</p>
          <h2 className={styles.sectionTitleTight}>Ship-ready, not just demo-ready.</h2>
          <ul className={styles.securityGrid}>
            <li>
              <h4>MCP versions pinned</h4>
              <p>Every .mcp.json and agent profile references awslabs MCP servers by exact PyPI version. No @latest supply-chain surprises.</p>
            </li>
            <li>
              <h4>Read-only EKS MCP</h4>
              <p>The Kiro agent profile does not enable --allow-write or --allow-sensitive-data-access by default; opt in explicitly.</p>
            </li>
            <li>
              <h4>Least-privilege IAM</h4>
              <p>langfuse-observability uses a bucket-scoped customer-managed policy. AmazonS3FullAccess is called out as a Bad Example.</p>
            </li>
            <li>
              <h4>Sandboxed expressions</h4>
              <p>cost-governance evaluates budget.yaml rules with simpleeval. Python eval() on user-editable config is a documented RCE vector.</p>
            </li>
            <li>
              <h4>Session state stays local</h4>
              <p>.omao/state, .omao/plans, .omao/logs, audit-trail output, and project memory are gitignored. Verbatim prompts never leave the machine.</p>
            </li>
            <li>
              <h4>Safe JSON hooks</h4>
              <p>session-start.sh requires jq or python3 and refuses to emit shell-interpolated JSON, preventing state-file injection into context.</p>
            </li>
          </ul>
        </div>
      </section>

      {/* CTA */}
      <section className={styles.cta}>
        <h2 className={styles.ctaTitle}>Ready to automate your AWS AIDLC?</h2>
        <p className={styles.ctaLede}>
          Clone the repo, run one install script, and start with a Tier-0 workflow that fits your team.
        </p>
        <div className={styles.heroCtaRow}>
          <Link className={styles.ctaPrimary} to={useBaseUrl('/docs/getting-started')}>
            Read the getting-started guide
          </Link>
          <a
            className={styles.ctaSecondary}
            href="https://github.com/aws-samples/sample-oh-my-aidlcops"
            target="_blank"
            rel="noreferrer"
          >
            Star on GitHub
          </a>
        </div>
      </section>
    </div>
  );
}
