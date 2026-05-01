import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Introduction',
    },
    {
      type: 'doc',
      id: 'getting-started',
      label: 'Getting Started',
    },
    {
      type: 'doc',
      id: 'philosophy-aidlc-meets-agenticops',
      label: 'Philosophy',
    },
    {
      type: 'category',
      label: 'Installation',
      collapsed: false,
      items: [
        'claude-code-setup',
        'kiro-setup',
      ],
    },
    {
      type: 'doc',
      id: 'tier-0-workflows',
      label: 'Tier-0 Workflows',
    },
    {
      type: 'doc',
      id: 'keyword-triggers',
      label: 'Keyword Triggers',
    },
    {
      type: 'doc',
      id: 'easy-button',
      label: 'Easy Button',
    },
    {
      type: 'category',
      label: 'Foundation',
      collapsed: false,
      items: [
        'ontology',
        'harness-dsl',
        'profile',
        'doctor',
      ],
    },
    {
      type: 'category',
      label: 'Governance',
      collapsed: true,
      items: [
        'support-policy',
        'telemetry',
        'contributing',
        'references',
        'releases-pipeline',
      ],
    },
    {
      type: 'link',
      label: 'Releases',
      href: '/releases',
    },
  ],
};

export default sidebars;
