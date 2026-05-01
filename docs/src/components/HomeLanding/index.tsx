import React, { useState } from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

type Plugin = {
  name: string;
  tagline: string;
  scope: string;
  skills: string;
};

const PLUGINS: Plugin[] = [
  {
    name: 'ai-infra',
    tagline: 'Build the runtime.',
    scope:
      'AI runtime infrastructure on AWS. Ships EKS + vLLM + Inference Gateway + Langfuse + GPU + guardrails today; Bedrock / SageMaker runtime skills planned. MCP servers pinned to exact PyPI versions — no @latest.',
    skills:
      'agentic-eks-bootstrap · vllm-serving-setup · inference-gateway-routing · langfuse-observability · gpu-resource-management · ai-gateway-guardrails',
  },
  {
    name: 'aidlc',
    tagline: 'Design and build with a spec.',
    scope:
      'AIDLC Phase 1 (Inception) + Phase 2 (Construction) opt-in extensions for awslabs/aidlc-workflows. Inception captures workspace, requirements, stories, and the workflow plan. Construction turns that plan into components, code, tests, and risk-discovered quality gates.',
    skills:
      'workspace-detection · requirements-analysis · user-stories · workflow-planning · component-design · code-generation · test-strategy · risk-discovery · quality-gates',
  },
  {
    name: 'agenticops',
    tagline: 'Operate with agents.',
    scope:
      'Autonomous operations for production agentic workloads. Incident response, self-improving feedback loops, progressive rollouts with SLO circuit breakers, cost governance with a simpleeval sandbox, and verbatim audit trails.',
    skills:
      'self-improving-loop · autopilot-deploy · incident-response · continuous-eval · cost-governance · audit-trail',
  },
  {
    name: 'modernization',
    tagline: 'Lift legacy onto AWS.',
    scope:
      'Brownfield legacy workload modernization using the AWS 6R strategy. Workload assessment with Five Lenses, 6R decision matrix, to-be architecture, containerization hardening, and production cutover planning with rollback triggers.',
    skills:
      'workload-assessment · modernization-strategy · to-be-architecture · containerization · cutover-planning',
  },
];

type Workflow = {
  keyword: string;
  command: string;
  scope: string;
};

const WORKFLOWS: Workflow[] = [
  {
    keyword: 'autopilot',
    command: '/oma:autopilot',
    scope: 'Full AIDLC loop (Inception → Construction → Operations).',
  },
  {
    keyword: 'aidlc-loop',
    command: '/oma:aidlc-loop',
    scope: 'Single-feature Inception → Construction pass.',
  },
  {
    keyword: 'inception',
    command: '/oma:inception',
    scope: 'AIDLC Phase 1 only — spec, stories, workflow plan.',
  },
  {
    keyword: 'construction',
    command: '/oma:construction',
    scope: 'AIDLC Phase 2 only — design, codegen, agentic TDD.',
  },
  {
    keyword: 'agenticops',
    command: '/oma:agenticops',
    scope: 'Operations mode: continuous-eval + incident-response + cost-governance.',
  },
  {
    keyword: 'self-improving',
    command: '/oma:self-improving',
    scope: 'Langfuse traces → prompt / skill improvement PR.',
  },
  {
    keyword: 'platform-bootstrap',
    command: '/oma:platform-bootstrap',
    scope: '5-checkpoint Agentic AI Platform bootstrap on EKS.',
  },
  {
    keyword: 'modernize',
    command: '/oma:modernize',
    scope: '6-stage brownfield modernization (assessment → cutover).',
  },
  {
    keyword: 'cancel',
    command: '/oma:cancel',
    scope: 'Terminate the active Tier-0 mode.',
  },
];

const SUPERPOWERS = [
  {
    num: '01',
    title: 'One command, entire lifecycle.',
    body:
      'Spec → design → code → canary deploy → self-healing → cost attribution. /oma:autopilot drives the whole loop and pauses only at explicit approval checkpoints.',
  },
  {
    num: '02',
    title: 'Self-improving from production traces.',
    body:
      'Langfuse traces feed /oma:self-improving. Failure patterns become draft PRs against the skills and prompts that produced them — regression tests run before the PR is opened.',
  },
  {
    num: '03',
    title: 'Humans approve. Agents execute.',
    body:
      'Every Tier-0 workflow sandwiches agent-driven diagnosis, proposal, and execution between explicit human gates. The agent never silently mutates production.',
  },
];

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
      '> /plugin install ai-infra agenticops aidlc modernization',
      '> /oma:platform-bootstrap',
      '  [1/5] Gather Context  …  ok',
      '  [2/5] Pre-flight      …  ok',
    ],
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

const FAQ = [
  {
    q: 'What does "Tech Preview" mean for this repo?',
    a: 'profile.yaml v1 and the 8 ontology schemas are stable; CLI surfaces and the doctor report shape may still evolve before GA. Breaking changes land in CHANGELOG under an explicit "Breaking" heading. See the support policy for the full stability contract.',
  },
  {
    q: 'Do I have to use both Claude Code and Kiro?',
    a: 'No. Pick one. The plugin directory, skills, and MCP server pinning are identical across harnesses; only the install script differs. The .omao/ state directory is harness-agnostic, so you can switch later without losing work.',
  },
  {
    q: 'What AWS permissions do I need to run the default workflows?',
    a: 'The EKS MCP server runs read-only by default (no --allow-write). /oma:platform-bootstrap needs eks:*, ec2:*, and iam:CreateRole against your cluster account. /oma:agenticops reads CloudWatch, Prometheus, and Cost Explorer. No credentials are collected or sent anywhere beyond your shell.',
  },
  {
    q: 'How does OMA relate to awslabs/aidlc-workflows?',
    a: 'OMA consumes aidlc-workflows as the core AIDLC spec and contributes only *.opt-in.md extension files into it. We do not fork the core workflow. scripts/install/aidlc-extensions.sh clones it at runtime and symlinks our opt-in overlays.',
  },
  {
    q: 'What happens to cost when I turn on /oma:agenticops?',
    a: 'cost-governance attributes spend per agent and enforces a monthly ceiling via Budget.action_on_breach. When the ceiling is in reach it drafts model-downgrade PRs (Opus → Sonnet → Haiku) and vetoes deploys until approved. No autonomous scaling happens without an explicit approval chain.',
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

const Faq = ({ items }: { items: typeof FAQ }) => {
  const [openIndex, setOpenIndex] = useState<number | null>(0);
  return (
    <ul className={styles.faqList}>
      {items.map((item, idx) => {
        const open = openIndex === idx;
        return (
          <li key={item.q} className={`${styles.faqItem} ${open ? styles.faqItemOpen : ''}`}>
            <button
              type="button"
              className={styles.faqTrigger}
              aria-expanded={open}
              onClick={() => setOpenIndex(open ? null : idx)}
            >
              <span>{item.q}</span>
              <svg
                viewBox="0 0 24 24"
                width="18"
                height="18"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                className={styles.faqChevron}
                aria-hidden="true"
              >
                <path d="M6 9l6 6 6-6" />
              </svg>
            </button>
            {open && <p className={styles.faqAnswer}>{item.a}</p>}
          </li>
        );
      })}
    </ul>
  );
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
              aws-samples · AIDLC × AgenticOps
            </div>
            <div className={styles.previewBadge} role="note">
              <span className={styles.previewBadgeLabel}>Tech Preview</span>
              <span className={styles.previewBadgeText}>
                v0.3.0-preview.1 — API may change before GA. See the{' '}
                <Link to={useBaseUrl('/docs/support-policy')}>support policy</Link>.
              </span>
            </div>
            <h1 className={styles.heroTitle}>
              The AIDLC operations gap<br />
              is still <span className={styles.accent}>human glue.</span>
            </h1>
            <p className={styles.heroLede}>
              AIDLC automates design and construction. Operations — deploys, incidents, cost
              drift, regressions — still fall on the team. OMA is the plugin marketplace that
              closes the loop with AgenticOps: humans approve, agents execute everything
              between the checkpoints.
            </p>
            <div className={styles.heroCtaRow}>
              <Link className={styles.ctaPrimary} to={useBaseUrl('/docs/getting-started')}>
                Install in 30 seconds
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
                Star on GitHub
              </a>
            </div>
            <dl className={styles.heroStats}>
              <div>
                <dt>Plugins</dt>
                <dd>4</dd>
              </div>
              <div>
                <dt>Tier-0 workflows</dt>
                <dd>9</dd>
              </div>
              <div>
                <dt>AWS MCP servers</dt>
                <dd>11 pinned</dd>
              </div>
              <div>
                <dt>Ontology entities</dt>
                <dd>8 schemas</dd>
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
                  <span className={styles.mono}>claude</span>
                </p>
                <p className={styles.mutedLight}>
                  &gt; /plugin marketplace add aws-samples/sample-oh-my-aidlcops
                </p>
                <p className={styles.mutedLight}>
                  &gt; /plugin install ai-infra agenticops aidlc modernization
                </p>
                <p className={styles.mutedLight}>
                  ✔ 4 plugins enabled · 11 AWS MCP servers pinned
                </p>
                <p className={styles.prompt}>
                  &gt; /oma:autopilot <em>"ship the anomaly detector end to end"</em>
                </p>
                <div className={styles.mockCallout}>
                  OMA · Inception → Construction → Operations.
                  Approval gates: 4. Agent steps in between: ~40.
                </div>
              </div>
            </div>
            <span className={styles.mockGlow1} aria-hidden="true" />
            <span className={styles.mockGlow2} aria-hidden="true" />
          </div>
        </div>
      </section>

      {/* PROBLEM -> SOLUTION CONTRAST */}
      <section className={styles.contrast}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>The gap</p>
          <h2 className={styles.sectionTitle}>
            Most AIDLC implementations stop at merge time.
          </h2>
        </header>
        <div className={styles.contrastGrid}>
          <article className={`${styles.contrastCard} ${styles.contrastBefore}`}>
            <h3>Without OMA</h3>
            <ul>
              <li>Traces pile up in Langfuse but never become PRs.</li>
              <li>Incident playbooks live in a wiki no on-call reads at 2am.</li>
              <li>Cost anomalies surface on the next month's invoice.</li>
              <li>Every operations decision is a human judgement call.</li>
            </ul>
          </article>
          <article className={`${styles.contrastCard} ${styles.contrastAfter}`}>
            <h3>With OMA</h3>
            <ul>
              <li>Trace patterns open draft PRs against the skills that caused them.</li>
              <li>SEV1 alarms get diagnosed + mitigated with a human approval gate.</li>
              <li>Budget breaches throttle or downgrade before the ceiling hits.</li>
              <li>Humans approve at checkpoints. Agents do the rest.</li>
            </ul>
          </article>
        </div>
      </section>

      {/* SUPERPOWERS */}
      <section className={styles.superpowers}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>What changes</p>
          <h2 className={styles.sectionTitle}>
            Three mechanisms that make AIDLC close itself.
          </h2>
        </header>
        <ol className={styles.superpowerList}>
          {SUPERPOWERS.map((s) => (
            <li key={s.num}>
              <span className={styles.superpowerNum}>{s.num}</span>
              <div>
                <h3>{s.title}</h3>
                <p>{s.body}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      {/* INTEGRATION */}
      <section className={styles.integration}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>Drop-in</p>
          <h2 className={styles.sectionTitle}>
            Ship as a plugin inside the tools you already run.
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
            <h2 className={styles.sectionTitleTight}>The AIDLC loop, closed.</h2>
            <p className={styles.loopLede}>
              Inception and Construction describe <em>what</em> will ship. Operations keeps it
              alive after it ships — and feeds learnings back to Construction without a human
              in the loop for routine corrections.
            </p>
            <ol className={styles.loopList}>
              <li>
                <span className={styles.loopStep}>1</span>
                <div>
                  <h4>Inception · <code>aidlc</code></h4>
                  <p>
                    Workspace detection, adaptive requirements, user stories, workflow plan.
                    Output artifacts become the contract Construction must honor.
                  </p>
                </div>
              </li>
              <li>
                <span className={styles.loopStep}>2</span>
                <div>
                  <h4>Construction · <code>aidlc</code></h4>
                  <p>
                    Component design, code generation with human-approved gates, 12-category
                    risk discovery, TDD for agentic systems, phase quality gates.
                  </p>
                </div>
              </li>
              <li>
                <span className={styles.loopStep}>3</span>
                <div>
                  <h4>Operations · <code>agenticops</code></h4>
                  <p>
                    Autopilot deploys, continuous eval, incident response, cost governance, and
                    the self-improving loop that feeds learnings back into Construction.
                  </p>
                </div>
              </li>
            </ol>
            <p className={styles.loopFoot}>
              Runtime (<code>ai-infra</code>) and brownfield entry (<code>modernization</code>)
              sit alongside the loop, not inside it.
            </p>
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

      {/* TIER-0 WORKFLOWS */}
      <section className={styles.workflows}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>Nine Tier-0 workflows</p>
          <h2 className={styles.sectionTitle}>
            Call one slash command. Get a checkpointed plan.
          </h2>
        </header>
        <div className={styles.workflowGrid}>
          {WORKFLOWS.map((w) => (
            <article key={w.command} className={styles.workflowCard}>
              <span className={styles.workflowKeyword}>{w.keyword}</span>
              <span className={styles.workflowCommand}>{w.command}</span>
              <p>{w.scope}</p>
            </article>
          ))}
        </div>
        <p className={styles.workflowFoot}>
          Keyword triggers auto-suggest the right command when your prompt contains a match.
          See the <Link to={useBaseUrl('/docs/keyword-triggers')}>trigger catalog</Link>.
        </p>
      </section>

      {/* PLUGINS */}
      <section className={styles.plugins}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>Four plugins</p>
          <h2 className={styles.sectionTitle}>
            Install only what you need — or all four with one marketplace command.
          </h2>
        </header>
        <div className={styles.pluginGrid}>
          {PLUGINS.map((p) => (
            <article key={p.name} className={styles.pluginCard}>
              <div className={styles.pluginHeading}>
                <span className={styles.pluginName}>{p.name}</span>
                <span className={styles.pluginTagline}>{p.tagline}</span>
              </div>
              <p>{p.scope}</p>
              <p className={styles.pluginSkills}>{p.skills}</p>
            </article>
          ))}
        </div>
      </section>

      {/* INSTALL */}
      <section className={styles.install}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>30-second install</p>
          <h2 className={styles.sectionTitle}>Three terminal lines to a working loop.</h2>
        </header>
        <div className={styles.installSteps}>
          <div className={styles.installStep}>
            <span className={styles.installNum}>1</span>
            <div>
              <h4>Register the marketplace</h4>
              <pre><code>{`claude
> /plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops`}</code></pre>
            </div>
          </div>
          <div className={styles.installStep}>
            <span className={styles.installNum}>2</span>
            <div>
              <h4>Install the four plugins</h4>
              <pre><code>{`> /plugin install ai-infra@oh-my-aidlcops
> /plugin install agenticops@oh-my-aidlcops
> /plugin install aidlc@oh-my-aidlcops
> /plugin install modernization@oh-my-aidlcops`}</code></pre>
            </div>
          </div>
          <div className={styles.installStep}>
            <span className={styles.installNum}>3</span>
            <div>
              <h4>Run a Tier-0 workflow</h4>
              <pre><code>{`> /oma:autopilot "ship the anomaly detector end to end"`}</code></pre>
              <p className={styles.installHint}>
                Or start with a safer on-ramp:{' '}
                <Link to={useBaseUrl('/docs/getting-started')}>getting-started guide</Link>.
              </p>
            </div>
          </div>
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

      {/* FAQ */}
      <section className={styles.faqSection}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>FAQ</p>
          <h2 className={styles.sectionTitle}>Common questions before you install.</h2>
        </header>
        <Faq items={FAQ} />
      </section>

      {/* CTA */}
      <section className={styles.cta}>
        <h2 className={styles.ctaTitle}>Stop running the operations loop by hand.</h2>
        <p className={styles.ctaLede}>
          Install once. Approve at the checkpoints. Let agents carry the rest of the AIDLC loop.
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
