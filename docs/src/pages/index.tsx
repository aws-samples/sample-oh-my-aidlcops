import React from 'react';
import Layout from '@theme/Layout';
import HomeLanding from '@site/src/components/HomeLanding';

export default function Home(): React.ReactElement {
  return (
    <Layout
      title="AIDLC × AgenticOps marketplace"
      description="Extend Claude Code and Kiro with AgenticOps plugins and skills that automate the AWS AI-Driven Development Lifecycle: Inception, Construction, Operations."
    >
      <HomeLanding />
    </Layout>
  );
}
