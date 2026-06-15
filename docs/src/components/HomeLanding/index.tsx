import React, { useState } from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Translate, { translate } from '@docusaurus/Translate';
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
    tagline: translate({
      id: 'landing.plugin.ai_infra.tagline',
      message: 'Build the runtime.',
      description: 'Tagline for ai-infra plugin',
    }),
    scope: translate({
      id: 'landing.plugin.ai_infra.scope',
      message:
        'AI runtime infrastructure on AWS. Ships EKS + vLLM + Inference Gateway + Langfuse + GPU + guardrails today; Bedrock / SageMaker runtime skills planned. MCP servers pinned to exact PyPI versions — no @latest.',
      description: 'Description of ai-infra plugin scope',
    }),
    skills:
      'agentic-eks-bootstrap · vllm-serving-setup · inference-gateway-routing · langfuse-observability · gpu-resource-management · ai-gateway-guardrails',
  },
  {
    name: 'aidlc',
    tagline: translate({
      id: 'landing.plugin.aidlc.tagline',
      message: 'Design and build with a spec.',
      description: 'Tagline for aidlc plugin',
    }),
    scope: translate({
      id: 'landing.plugin.aidlc.scope',
      message:
        'AIDLC Phase 1 (Inception) + Phase 2 (Construction) opt-in extensions for awslabs/aidlc-workflows. Inception captures workspace, requirements, stories, and the workflow plan. Construction turns that plan into components, code, tests, and risk-discovered quality gates.',
      description: 'Description of aidlc plugin scope',
    }),
    skills:
      'workspace-detection · requirements-analysis · user-stories · workflow-planning · component-design · code-generation · test-strategy · risk-discovery · quality-gates',
  },
  {
    name: 'agenticops',
    tagline: translate({
      id: 'landing.plugin.agenticops.tagline',
      message: 'Operate with agents.',
      description: 'Tagline for agenticops plugin',
    }),
    scope: translate({
      id: 'landing.plugin.agenticops.scope',
      message:
        'Autonomous operations for production agentic workloads. Incident response, self-improving feedback loops, progressive rollouts with SLO circuit breakers, cost governance with a simpleeval sandbox, and verbatim audit trails.',
      description: 'Description of agenticops plugin scope',
    }),
    skills:
      'self-improving-loop · autopilot-deploy · incident-response · continuous-eval · cost-governance · audit-trail',
  },
  {
    name: 'modernization',
    tagline: translate({
      id: 'landing.plugin.modernization.tagline',
      message: 'Lift legacy onto AWS.',
      description: 'Tagline for modernization plugin',
    }),
    scope: translate({
      id: 'landing.plugin.modernization.scope',
      message:
        'Brownfield legacy workload modernization using the AWS 6R strategy. Workload assessment with Five Lenses, 6R decision matrix, to-be architecture, containerization hardening, and production cutover planning with rollback triggers.',
      description: 'Description of modernization plugin scope',
    }),
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
    scope: translate({
      id: 'landing.workflow.autopilot.scope',
      message: 'Full AIDLC loop (Inception → Construction → Operations).',
      description: 'Description of autopilot workflow',
    }),
  },
  {
    keyword: 'aidlc-loop',
    command: '/oma:aidlc-loop',
    scope: translate({
      id: 'landing.workflow.aidlc_loop.scope',
      message: 'Single-feature Inception → Construction pass.',
      description: 'Description of aidlc-loop workflow',
    }),
  },
  {
    keyword: 'inception',
    command: '/oma:inception',
    scope: translate({
      id: 'landing.workflow.inception.scope',
      message: 'AIDLC Phase 1 only — spec, stories, workflow plan.',
      description: 'Description of inception workflow',
    }),
  },
  {
    keyword: 'construction',
    command: '/oma:construction',
    scope: translate({
      id: 'landing.workflow.construction.scope',
      message: 'AIDLC Phase 2 only — design, codegen, agentic TDD.',
      description: 'Description of construction workflow',
    }),
  },
  {
    keyword: 'agenticops',
    command: '/oma:agenticops',
    scope: translate({
      id: 'landing.workflow.agenticops.scope',
      message: 'Operations mode: continuous-eval + incident-response + cost-governance.',
      description: 'Description of agenticops workflow',
    }),
  },
  {
    keyword: 'self-improving',
    command: '/oma:self-improving',
    scope: translate({
      id: 'landing.workflow.self_improving.scope',
      message: 'Langfuse traces (via your configured trace MCP) → prompt / skill improvement PR.',
      description: 'Description of self-improving workflow',
    }),
  },
  {
    keyword: 'platform-bootstrap',
    command: '/oma:platform-bootstrap',
    scope: translate({
      id: 'landing.workflow.platform_bootstrap.scope',
      message: '5-checkpoint Agentic AI Platform bootstrap on EKS.',
      description: 'Description of platform-bootstrap workflow',
    }),
  },
  {
    keyword: 'modernize',
    command: '/oma:modernize',
    scope: translate({
      id: 'landing.workflow.modernize.scope',
      message: '6-stage brownfield modernization (assessment → cutover).',
      description: 'Description of modernize workflow',
    }),
  },
  {
    keyword: 'cancel',
    command: '/oma:cancel',
    scope: translate({
      id: 'landing.workflow.cancel.scope',
      message: 'Terminate the active Tier-0 mode.',
      description: 'Description of cancel workflow',
    }),
  },
];

const SUPERPOWERS = [
  {
    num: '01',
    title: translate({
      id: 'landing.superpower.1.title',
      message: 'One command, entire lifecycle.',
      description: 'Title for superpower 1',
    }),
    body: translate({
      id: 'landing.superpower.1.body',
      message:
        'Spec → design → code → canary deploy → self-healing → cost attribution. /oma:autopilot drives the whole loop and pauses only at explicit approval checkpoints.',
      description: 'Body text for superpower 1',
    }),
  },
  {
    num: '02',
    title: translate({
      id: 'landing.superpower.2.title',
      message: 'Self-improving from production traces.',
      description: 'Title for superpower 2',
    }),
    body: translate({
      id: 'landing.superpower.2.body',
      message:
        'When you configure your own Langfuse + trace-reading MCP (via profile observability.trace_mcp), traces feed /oma:self-improving. Failure patterns become draft PRs against the skills and prompts that produced them — regression tests run before the PR is opened.',
      description: 'Body text for superpower 2',
    }),
  },
  {
    num: '03',
    title: translate({
      id: 'landing.superpower.3.title',
      message: 'Humans approve. Agents execute.',
      description: 'Title for superpower 3',
    }),
    body: translate({
      id: 'landing.superpower.3.body',
      message:
        'Every Tier-0 workflow sandwiches agent-driven diagnosis, proposal, and execution between explicit human gates. The agent never silently mutates production.',
      description: 'Body text for superpower 3',
    }),
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
    title: translate({
      id: 'landing.capability.autopilot.title',
      message: 'Autopilot deploys',
      description: 'Title for autopilot deploys capability',
    }),
    body: translate({
      id: 'landing.capability.autopilot.body',
      message:
        'autopilot-deploy runs canary 1% → 10% → 50% → 100% with SLO-gated circuit breakers. Each stage waits for continuous-eval before promotion; regression trips auto-rollback.',
      description: 'Body text for autopilot deploys capability',
    }),
    icon: 'rocket',
    variant: 'wide',
    bullets: [
      translate({
        id: 'landing.capability.autopilot.bullet1',
        message: 'Argo Rollouts / Flagger',
        description: 'First bullet for autopilot deploys',
      }),
      translate({
        id: 'landing.capability.autopilot.bullet2',
        message: 'Prometheus SLO gates',
        description: 'Second bullet for autopilot deploys',
      }),
      translate({
        id: 'landing.capability.autopilot.bullet3',
        message: 'Human approval at 100%',
        description: 'Third bullet for autopilot deploys',
      }),
    ],
  },
  {
    title: translate({
      id: 'landing.capability.self_healing.title',
      message: 'Self-healing',
      description: 'Title for self-healing capability',
    }),
    body: translate({
      id: 'landing.capability.self_healing.body',
      message:
        'incident-response classifies SEV1–4, pulls the matching runbook, issues diagnostic MCP queries, and drafts a remediation script for approval. SEV1 pages on-call; it never acts.',
      description: 'Body text for self-healing capability',
    }),
    icon: 'shield',
    variant: 'accent',
  },
  {
    title: translate({
      id: 'landing.capability.cost_governance.title',
      message: 'Cost governance',
      description: 'Title for cost governance capability',
    }),
    body: translate({
      id: 'landing.capability.cost_governance.body',
      message:
        'cost-governance attributes spend per agent, vetoes deploys that would breach the monthly ceiling, and drafts Opus → Sonnet → Haiku downgrade PRs. budget.yaml runs in a simpleeval sandbox — no Python eval, no RCE vector.',
      description: 'Body text for cost governance capability',
    }),
    icon: 'coin',
    variant: 'quiet',
  },
  {
    title: translate({
      id: 'landing.capability.cli_first.title',
      message: 'CLI first. Always.',
      description: 'Title for CLI first capability',
    }),
    body: translate({
      id: 'landing.capability.cli_first.body',
      message:
        'Every skill is reachable as a slash command in Claude Code or a direct skill call in Kiro. The full state lives under .omao/ and is portable between harnesses.',
      description: 'Body text for CLI first capability',
    }),
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
    title: translate({
      id: 'landing.integration.claude_code.title',
      message: 'Claude Code plugin',
      description: 'Title for Claude Code integration',
    }),
    icon: 'plug',
    body: translate({
      id: 'landing.integration.claude_code.body',
      message:
        'Ship as a native Claude Code marketplace entry. Slash commands, keyword triggers, and the AWS hosted MCP layer work out of the box.',
      description: 'Body text for Claude Code integration',
    }),
  },
  {
    title: translate({
      id: 'landing.integration.kiro.title',
      message: 'Kiro skills',
      description: 'Title for Kiro integration',
    }),
    icon: 'spark',
    body: translate({
      id: 'landing.integration.kiro.body',
      message:
        'install/kiro.sh symlinks every skill into ~/.kiro/skills/ and wires kiro-agents profiles with pinned MCP server versions.',
      description: 'Body text for Kiro integration',
    }),
  },
  {
    title: translate({
      id: 'landing.integration.shared_state.title',
      message: 'Shared .omao state',
      description: 'Title for shared state integration',
    }),
    icon: 'layers',
    body: translate({
      id: 'landing.integration.shared_state.body',
      message:
        'Tier-0 mode, project memory, and audit logs live in .omao/. Both harnesses read and write the same directory — switch without losing context.',
      description: 'Body text for shared state integration',
    }),
  },
];

const FAQ = [
  {
    q: translate({
      id: 'landing.faq.q1.q',
      message: 'What does "Tech Preview" mean for this repo?',
      description: 'FAQ question 1',
    }),
    a: translate({
      id: 'landing.faq.q1.a',
      message:
        'profile.yaml v1 and the 8 ontology schemas are stable; CLI surfaces and the doctor report shape may still evolve before GA. Breaking changes land in CHANGELOG under an explicit "Breaking" heading. See the support policy for the full stability contract.',
      description: 'FAQ answer 1',
    }),
  },
  {
    q: translate({
      id: 'landing.faq.q2.q',
      message: 'Do I have to use both Claude Code and Kiro?',
      description: 'FAQ question 2',
    }),
    a: translate({
      id: 'landing.faq.q2.a',
      message:
        'No. Pick one. The plugin directory, skills, and MCP server pinning are identical across harnesses; only the install script differs. The .omao/ state directory is harness-agnostic, so you can switch later without losing work.',
      description: 'FAQ answer 2',
    }),
  },
  {
    q: translate({
      id: 'landing.faq.q3.q',
      message: 'What AWS permissions do I need to run the default workflows?',
      description: 'FAQ question 3',
    }),
    a: translate({
      id: 'landing.faq.q3.a',
      message:
        'The EKS MCP server runs read-only by default (no --allow-write). /oma:platform-bootstrap needs eks:*, ec2:*, and iam:CreateRole against your cluster account. /oma:agenticops reads CloudWatch, Prometheus, and Cost Explorer. No credentials are collected or sent anywhere beyond your shell.',
      description: 'FAQ answer 3',
    }),
  },
  {
    q: translate({
      id: 'landing.faq.q4.q',
      message: 'How does OMA relate to awslabs/aidlc-workflows?',
      description: 'FAQ question 4',
    }),
    a: translate({
      id: 'landing.faq.q4.a',
      message:
        'OMA consumes aidlc-workflows as the core AIDLC spec and contributes only *.opt-in.md extension files into it. We do not fork the core workflow. scripts/install/aidlc-extensions.sh clones it at runtime and symlinks our opt-in overlays.',
      description: 'FAQ answer 4',
    }),
  },
  {
    q: translate({
      id: 'landing.faq.q5.q',
      message: 'What happens to cost when I turn on /oma:agenticops?',
      description: 'FAQ question 5',
    }),
    a: translate({
      id: 'landing.faq.q5.a',
      message:
        'cost-governance attributes spend per agent and enforces a monthly ceiling via Budget.action_on_breach. When the ceiling is in reach it drafts model-downgrade PRs (Opus → Sonnet → Haiku) and vetoes deploys until approved. No autonomous scaling happens without an explicit approval chain.',
      description: 'FAQ answer 5',
    }),
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
        <div className={styles.previewBadge} role="note">
          <span className={styles.previewBadgeLabel}>
            <Translate id="landing.hero.preview_badge" description="Tech preview badge label">
              Tech Preview
            </Translate>
          </span>
          <span className={styles.previewBadgeText}>
            <Translate id="landing.hero.preview_text" description="Tech preview description text">
              v0.4.0-preview.1 — schemas &amp; DSL may change before GA. See the
            </Translate>{' '}
            <Link to={useBaseUrl('/docs/support-policy')}>
              <Translate id="landing.hero.support_policy_link" description="Support policy link text">
                support policy
              </Translate>
            </Link>.
          </span>
        </div>
        <div className={styles.heroGrid}>
          <div className={styles.heroCopy}>
            <div className={styles.eyebrow}>
              <span className={styles.eyebrowDot} aria-hidden="true" />
              <Translate id="landing.hero.eyebrow" description="Hero eyebrow text">
                aws-samples · AIDLC × AgenticOps
              </Translate>
            </div>
            <h1 className={styles.heroTitle}>
              <Translate id="landing.hero.title_line1" description="Hero main title line 1">
                The AIDLC operations gap
              </Translate>
              <br />
              <Translate id="landing.hero.title_line2_before" description="Hero title line 2 before accent">
                is still
              </Translate>{' '}
              <span className={styles.accent}>
                <Translate id="landing.hero.title_line2_accent" description="Hero title line 2 accent text">
                  human glue.
                </Translate>
              </span>
            </h1>
            <p className={styles.heroLede}>
              <Translate id="landing.hero.lede" description="Hero lead paragraph">
                AIDLC automates design and construction. Operations — deploys, incidents, cost
                drift, regressions — still fall on the team. OMA is the plugin marketplace that
                closes the loop with AgenticOps: humans approve, agents execute everything
                between the checkpoints.
              </Translate>
            </p>
            <div className={styles.heroCtaRow}>
              <Link className={styles.ctaPrimary} to={useBaseUrl('/docs/getting-started')}>
                <Translate id="landing.hero.cta_primary" description="Primary CTA button text">
                  Install in 30 seconds
                </Translate>
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
                <Translate id="landing.hero.cta_secondary" description="Secondary CTA button text">
                  Star on GitHub
                </Translate>
              </a>
            </div>
            <dl className={styles.heroStats}>
              <div>
                <dt>
                  <Translate id="landing.hero.stat1_label" description="Stat 1 label">
                    Plugins
                  </Translate>
                </dt>
                <dd>4</dd>
              </div>
              <div>
                <dt>
                  <Translate id="landing.hero.stat2_label" description="Stat 2 label">
                    Tier-0 workflows
                  </Translate>
                </dt>
                <dd>9</dd>
              </div>
              <div>
                <dt>
                  <Translate id="landing.hero.stat3_label" description="Stat 3 label">
                    AWS MCP servers
                  </Translate>
                </dt>
                <dd>
                  <Translate id="landing.hero.stat3_value" description="Stat 3 value">
                    11 pinned
                  </Translate>
                </dd>
              </div>
              <div>
                <dt>
                  <Translate id="landing.hero.stat4_label" description="Stat 4 label">
                    Ontology entities
                  </Translate>
                </dt>
                <dd>
                  <Translate id="landing.hero.stat4_value" description="Stat 4 value">
                    8 schemas
                  </Translate>
                </dd>
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
                  <Translate id="landing.hero.mock_callout" description="Hero mock terminal callout text">
                    OMA · Inception → Construction → Operations.
                    Approval gates: 4. Agent steps in between: ~40.
                  </Translate>
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
          <p className={styles.kicker}>
            <Translate id="landing.contrast.kicker" description="Contrast section kicker">
              The gap
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.contrast.title" description="Contrast section title">
              Most AIDLC implementations stop at merge time.
            </Translate>
          </h2>
        </header>
        <div className={styles.contrastGrid}>
          <article className={`${styles.contrastCard} ${styles.contrastBefore}`}>
            <h3>
              <Translate id="landing.contrast.without_title" description="Without OMA heading">
                Without OMA
              </Translate>
            </h3>
            <ul>
              <li>
                <Translate id="landing.contrast.without_bullet1" description="Without OMA bullet 1">
                  Traces pile up in Langfuse but never become PRs.
                </Translate>
              </li>
              <li>
                <Translate id="landing.contrast.without_bullet2" description="Without OMA bullet 2">
                  Incident playbooks live in a wiki no on-call reads at 2am.
                </Translate>
              </li>
              <li>
                <Translate id="landing.contrast.without_bullet3" description="Without OMA bullet 3">
                  Cost anomalies surface on the next month's invoice.
                </Translate>
              </li>
              <li>
                <Translate id="landing.contrast.without_bullet4" description="Without OMA bullet 4">
                  Every operations decision is a human judgement call.
                </Translate>
              </li>
            </ul>
          </article>
          <article className={`${styles.contrastCard} ${styles.contrastAfter}`}>
            <h3>
              <Translate id="landing.contrast.with_title" description="With OMA heading">
                With OMA
              </Translate>
            </h3>
            <ul>
              <li>
                <Translate id="landing.contrast.with_bullet1" description="With OMA bullet 1">
                  Trace patterns open draft PRs against the skills that caused them (once you point OMA at your Langfuse trace MCP).
                </Translate>
              </li>
              <li>
                <Translate id="landing.contrast.with_bullet2" description="With OMA bullet 2">
                  SEV1 alarms get diagnosed + mitigated with a human approval gate.
                </Translate>
              </li>
              <li>
                <Translate id="landing.contrast.with_bullet3" description="With OMA bullet 3">
                  Budget breaches throttle or downgrade before the ceiling hits.
                </Translate>
              </li>
              <li>
                <Translate id="landing.contrast.with_bullet4" description="With OMA bullet 4">
                  Humans approve at checkpoints. Agents do the rest.
                </Translate>
              </li>
            </ul>
          </article>
        </div>
      </section>

      {/* SUPERPOWERS */}
      <section className={styles.superpowers}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>
            <Translate id="landing.superpowers.kicker" description="Superpowers section kicker">
              What changes
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.superpowers.title" description="Superpowers section title">
              Three mechanisms that make AIDLC close itself.
            </Translate>
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
          <p className={styles.kicker}>
            <Translate id="landing.integration.kicker" description="Integration section kicker">
              Drop-in
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.integration.title" description="Integration section title">
              Ship as a plugin inside the tools you already run.
            </Translate>
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
            <h2 className={styles.sectionTitleTight}>
              <Translate id="landing.loop.title" description="AIDLC loop section title">
                The AIDLC loop, closed.
              </Translate>
            </h2>
            <p className={styles.loopLede}>
              <Translate id="landing.loop.lede_before_em" description="AIDLC loop lead paragraph before emphasis">
                Inception and Construction describe
              </Translate>{' '}
              <em>
                <Translate id="landing.loop.lede_em" description="AIDLC loop lead paragraph emphasis">
                  what
                </Translate>
              </em>{' '}
              <Translate id="landing.loop.lede_after_em" description="AIDLC loop lead paragraph after emphasis">
                will ship. Operations keeps it alive after it ships — and feeds learnings back to Construction without a human in the loop for routine corrections.
              </Translate>
            </p>
            <ol className={styles.loopList}>
              <li>
                <span className={styles.loopStep}>1</span>
                <div>
                  <h4>
                    <Translate id="landing.loop.step1_title" description="Loop step 1 title">
                      Inception
                    </Translate>{' · '}
                    <code>aidlc</code>
                  </h4>
                  <p>
                    <Translate id="landing.loop.step1_body" description="Loop step 1 body">
                      Workspace detection, adaptive requirements, user stories, workflow plan.
                      Output artifacts become the contract Construction must honor.
                    </Translate>
                  </p>
                </div>
              </li>
              <li>
                <span className={styles.loopStep}>2</span>
                <div>
                  <h4>
                    <Translate id="landing.loop.step2_title" description="Loop step 2 title">
                      Construction
                    </Translate>{' · '}
                    <code>aidlc</code>
                  </h4>
                  <p>
                    <Translate id="landing.loop.step2_body" description="Loop step 2 body">
                      Component design, code generation with human-approved gates, 12-category
                      risk discovery, TDD for agentic systems, phase quality gates.
                    </Translate>
                  </p>
                </div>
              </li>
              <li>
                <span className={styles.loopStep}>3</span>
                <div>
                  <h4>
                    <Translate id="landing.loop.step3_title" description="Loop step 3 title">
                      Operations
                    </Translate>{' · '}
                    <code>agenticops</code>
                  </h4>
                  <p>
                    <Translate id="landing.loop.step3_body" description="Loop step 3 body">
                      Autopilot deploys, continuous eval, incident response, cost governance, and
                      the self-improving loop that feeds learnings back into Construction.
                    </Translate>
                  </p>
                </div>
              </li>
            </ol>
            <p className={styles.loopFoot}>
              <Translate id="landing.loop.footer_before_ai_infra" description="AIDLC loop footer before ai-infra">
                Runtime (
              </Translate>
              <code>ai-infra</code>
              <Translate id="landing.loop.footer_between" description="AIDLC loop footer between code blocks">
                ) and brownfield entry (
              </Translate>
              <code>modernization</code>
              <Translate id="landing.loop.footer_after_modernization" description="AIDLC loop footer after modernization">
                ) sit alongside the loop, not inside it.
              </Translate>
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
          <p className={styles.kicker}>
            <Translate id="landing.capabilities.kicker" description="Capabilities section kicker">
              AgenticOps capabilities
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.capabilities.title" description="Capabilities section title">
              Purpose-built for the autonomous era.
            </Translate>
          </h2>
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
          <p className={styles.kicker}>
            <Translate id="landing.workflows.kicker" description="Workflows section kicker">
              Nine Tier-0 workflows
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.workflows.title" description="Workflows section title">
              Call one slash command. Get a checkpointed plan.
            </Translate>
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
          <Translate id="landing.workflows.footer" description="Workflows footer text">
            Keyword triggers auto-suggest the right command when your prompt contains a match. See the
          </Translate>{' '}
          <Link to={useBaseUrl('/docs/keyword-triggers')}>
            <Translate id="landing.workflows.trigger_catalog_link" description="Trigger catalog link text">
              trigger catalog
            </Translate>
          </Link>.
        </p>
      </section>

      {/* PLUGINS */}
      <section className={styles.plugins}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>
            <Translate id="landing.plugins.kicker" description="Plugins section kicker">
              Four plugins
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.plugins.title" description="Plugins section title">
              Install only what you need — or all four with one marketplace command.
            </Translate>
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
          <p className={styles.kicker}>
            <Translate id="landing.install.kicker" description="Install section kicker">
              30-second install
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.install.title" description="Install section title">
              Three terminal lines to a working loop.
            </Translate>
          </h2>
        </header>
        <div className={styles.installSteps}>
          <div className={styles.installStep}>
            <span className={styles.installNum}>1</span>
            <div>
              <h4>
                <Translate id="landing.install.step1_title" description="Install step 1 title">
                  Register the marketplace
                </Translate>
              </h4>
              <pre><code>{`claude
> /plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops`}</code></pre>
            </div>
          </div>
          <div className={styles.installStep}>
            <span className={styles.installNum}>2</span>
            <div>
              <h4>
                <Translate id="landing.install.step2_title" description="Install step 2 title">
                  Install the four plugins
                </Translate>
              </h4>
              <pre><code>{`> /plugin install ai-infra@oh-my-aidlcops
> /plugin install agenticops@oh-my-aidlcops
> /plugin install aidlc@oh-my-aidlcops
> /plugin install modernization@oh-my-aidlcops`}</code></pre>
            </div>
          </div>
          <div className={styles.installStep}>
            <span className={styles.installNum}>3</span>
            <div>
              <h4>
                <Translate id="landing.install.step3_title" description="Install step 3 title">
                  Run a Tier-0 workflow
                </Translate>
              </h4>
              <pre><code>{`> /oma:autopilot "ship the anomaly detector end to end"`}</code></pre>
              <p className={styles.installHint}>
                <Translate id="landing.install.hint" description="Install hint text">
                  Or start with a safer on-ramp:
                </Translate>{' '}
                <Link to={useBaseUrl('/docs/getting-started')}>
                  <Translate id="landing.install.guide_link" description="Getting started guide link text">
                    getting-started guide
                  </Translate>
                </Link>.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* SECURITY */}
      <section className={styles.security}>
        <div className={styles.securityInner}>
          <p className={styles.kicker}>
            <Translate id="landing.security.kicker" description="Security section kicker">
              Secure by default
            </Translate>
          </p>
          <h2 className={styles.sectionTitleTight}>
            <Translate id="landing.security.title" description="Security section title">
              Ship-ready, not just demo-ready.
            </Translate>
          </h2>
          <ul className={styles.securityGrid}>
            <li>
              <h4>
                <Translate id="landing.security.item1_title" description="Security item 1 title">
                  MCP versions pinned
                </Translate>
              </h4>
              <p>
                <Translate id="landing.security.item1_body" description="Security item 1 body">
                  Every .mcp.json and agent profile references awslabs MCP servers by exact PyPI version. No @latest supply-chain surprises.
                </Translate>
              </p>
            </li>
            <li>
              <h4>
                <Translate id="landing.security.item2_title" description="Security item 2 title">
                  Read-only EKS MCP
                </Translate>
              </h4>
              <p>
                <Translate id="landing.security.item2_body" description="Security item 2 body">
                  The Kiro agent profile does not enable --allow-write or --allow-sensitive-data-access by default; opt in explicitly.
                </Translate>
              </p>
            </li>
            <li>
              <h4>
                <Translate id="landing.security.item3_title" description="Security item 3 title">
                  Least-privilege IAM
                </Translate>
              </h4>
              <p>
                <Translate id="landing.security.item3_body" description="Security item 3 body">
                  langfuse-observability uses a bucket-scoped customer-managed policy. AmazonS3FullAccess is called out as a Bad Example.
                </Translate>
              </p>
            </li>
            <li>
              <h4>
                <Translate id="landing.security.item4_title" description="Security item 4 title">
                  Sandboxed expressions
                </Translate>
              </h4>
              <p>
                <Translate id="landing.security.item4_body" description="Security item 4 body">
                  cost-governance evaluates budget.yaml rules with simpleeval. Python eval() on user-editable config is a documented RCE vector.
                </Translate>
              </p>
            </li>
            <li>
              <h4>
                <Translate id="landing.security.item5_title" description="Security item 5 title">
                  Session state stays local
                </Translate>
              </h4>
              <p>
                <Translate id="landing.security.item5_body" description="Security item 5 body">
                  .omao/state, .omao/plans, .omao/logs, audit-trail output, and project memory are gitignored. Verbatim prompts never leave the machine.
                </Translate>
              </p>
            </li>
            <li>
              <h4>
                <Translate id="landing.security.item6_title" description="Security item 6 title">
                  Safe JSON hooks
                </Translate>
              </h4>
              <p>
                <Translate id="landing.security.item6_body" description="Security item 6 body">
                  session-start.sh requires jq or python3 and refuses to emit shell-interpolated JSON, preventing state-file injection into context.
                </Translate>
              </p>
            </li>
          </ul>
        </div>
      </section>

      {/* FAQ */}
      <section className={styles.faqSection}>
        <header className={styles.sectionHead}>
          <p className={styles.kicker}>
            <Translate id="landing.faq.kicker" description="FAQ section kicker">
              FAQ
            </Translate>
          </p>
          <h2 className={styles.sectionTitle}>
            <Translate id="landing.faq.title" description="FAQ section title">
              Common questions before you install.
            </Translate>
          </h2>
        </header>
        <Faq items={FAQ} />
      </section>

      {/* CTA */}
      <section className={styles.cta}>
        <h2 className={styles.ctaTitle}>
          <Translate id="landing.cta.title" description="Final CTA title">
            Stop running the operations loop by hand.
          </Translate>
        </h2>
        <p className={styles.ctaLede}>
          <Translate id="landing.cta.lede" description="Final CTA lead text">
            Install once. Approve at the checkpoints. Let agents carry the rest of the AIDLC loop.
          </Translate>
        </p>
        <div className={styles.heroCtaRow}>
          <Link className={styles.ctaPrimary} to={useBaseUrl('/docs/getting-started')}>
            <Translate id="landing.cta.primary" description="Final CTA primary button">
              Read the getting-started guide
            </Translate>
          </Link>
          <a
            className={styles.ctaSecondary}
            href="https://github.com/aws-samples/sample-oh-my-aidlcops"
            target="_blank"
            rel="noreferrer"
          >
            <Translate id="landing.cta.secondary" description="Final CTA secondary button">
              Star on GitHub
            </Translate>
          </a>
        </div>
      </section>
    </div>
  );
}
