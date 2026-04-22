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
  ],
};

export default sidebars;
