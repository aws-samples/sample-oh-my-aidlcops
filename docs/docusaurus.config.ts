import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import { themes as prismThemes } from 'prism-react-renderer';

const config: Config = {
  title: 'oh-my-aidlcops',
  tagline: 'AIDLC × AgenticOps — plugin marketplace for agent-driven development lifecycle',
  favicon: 'img/favicon.ico',

  // Enable Mermaid diagrams (Docusaurus 3.x built-in).
  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },
  themes: ['@docusaurus/theme-mermaid'],

  // Production URL + baseUrl (GitHub Pages).
  url: 'https://aws-samples.github.io',
  baseUrl: '/sample-oh-my-aidlcops/',

  // GitHub Pages deployment.
  organizationName: 'aws-samples',
  projectName: 'sample-oh-my-aidlcops',
  deploymentBranch: 'gh-pages',
  trailingSlash: false,

  // Link hygiene: warn during dev, tighten to 'throw' once stable.
  onBrokenLinks: 'warn',

  // Internationalization — Korean default, English secondary.
  i18n: {
    defaultLocale: 'ko',
    locales: ['ko', 'en'],
    localeConfigs: {
      ko: { label: '한국어' },
      en: { label: 'English' },
    },
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: 'docs',
          path: 'docs',
          editUrl:
            'https://github.com/aws-samples/sample-oh-my-aidlcops/tree/main/docs/',
          showLastUpdateAuthor: false,
          showLastUpdateTime: false,
          breadcrumbs: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          changefreq: 'weekly',
          priority: 0.5,
          ignorePatterns: ['/tags/**'],
          filename: 'sitemap.xml',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: false,
    },
    mermaid: {
      theme: {
        light: 'neutral',
        dark: 'dark',
      },
    },
    docs: {
      sidebar: {
        hideable: true,
        autoCollapseCategories: false,
      },
    },
    image: 'img/oma-social-card.jpg',
    navbar: {
      title: 'OMA',
      logo: {
        alt: 'oh-my-aidlcops',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docs',
          position: 'left',
          label: 'Docs',
        },
        {
          type: 'localeDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/aws-samples/sample-oh-my-aidlcops',
          position: 'right',
          className: 'header-github-link',
          'aria-label': 'GitHub repository',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            { label: 'Introduction', to: '/docs/intro' },
            { label: 'Getting Started', to: '/docs/getting-started' },
            { label: 'Tier-0 Workflows', to: '/docs/tier-0-workflows' },
          ],
        },
        {
          title: 'Install',
          items: [
            { label: 'Claude Code Setup', to: '/docs/claude-code-setup' },
            { label: 'Kiro Setup', to: '/docs/kiro-setup' },
            { label: 'Keyword Triggers', to: '/docs/keyword-triggers' },
          ],
        },
        {
          title: 'Project',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/aws-samples/sample-oh-my-aidlcops',
            },
            {
              label: 'LICENSE (Apache-2.0)',
              href: 'https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/LICENSE',
            },
            {
              label: 'NOTICE',
              href: 'https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE',
            },
            {
              label: 'oh-my-claudecode',
              href: 'https://github.com/Yeachan-Heo/oh-my-claudecode',
            },
          ],
        },
      ],
      copyright: `Copyright ${new Date().getFullYear()} Amazon.com, Inc. or its affiliates. MIT-0 licensed.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'json', 'hcl', 'python', 'docker'],
    },
    metadata: [
      { name: 'keywords', content: 'AIDLC, AgenticOps, Claude Code, Kiro, plugin marketplace, AWS, EKS, agentic AI' },
      { property: 'og:type', content: 'website' },
      { property: 'og:site_name', content: 'oh-my-aidlcops' },
    ],
  } satisfies Preset.ThemeConfig,
};

export default config;
