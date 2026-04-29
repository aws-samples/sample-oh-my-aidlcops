# oh-my-aidlcops Documentation

This directory contains the Docusaurus-based documentation site for oh-my-aidlcops (OMA).

## Build Requirements

**Node.js Version:** Node 20 LTS is required for building the documentation site.

- **Node 22.x** is currently incompatible with Docusaurus 3.9.2 due to a webpack ProgressPlugin schema validation issue
- **Node 20.x** (LTS) works reliably

### Switch to Node 20

If you have `nvm` installed:

```bash
nvm install 20
nvm use 20
```

Or download Node 20 LTS from: https://nodejs.org/

## Build Instructions

```bash
cd docs
npm install
npm run build
```

The built site will be in `docs/build/`.

## Development

```bash
npm start
```

This starts a local development server at `http://localhost:3000/oh-my-aidlcops/`.

## Known Issues

- **Node 22 compatibility**: Docusaurus versions 3.5.2, 3.7.0, and 3.9.2 all fail with Node 22.22.2 due to webpack's ProgressPlugin schema validation error. This is a known upstream issue with Node 22's stricter validation.

## Deployment

The site is automatically deployed to GitHub Pages when changes are pushed to `main`.

Production URL: https://aws-samples.github.io/sample-oh-my-aidlcops/
