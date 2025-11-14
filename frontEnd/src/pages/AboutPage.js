import React from 'react';
import './AboutPage.css';

function AboutPage() {
  return (
    <main className="about-page" aria-labelledby="about-title">
      <section className="about-hero">
        <h1 id="about-title">About the Contoso RAG Platform</h1>
        <p className="about-subtitle">
          A modern Retrieval-Augmented Generation solution delivering explainable sales intelligence for Contoso Retail.
        </p>
      </section>

      <section className="about-owner" aria-labelledby="owner-heading">
        <h2 id="owner-heading">Created by Timur Makimov</h2>
        <p className="owner-role">Software Developer · Solution Architect · Builder of this project</p>
        <div className="owner-links">
          <a href="https://www.linkedin.com/in/timur-makimov-67703512/" target="_blank" rel="noopener noreferrer">
            LinkedIn Profile
          </a>
          <a href="https://github.com/megapers/" target="_blank" rel="noopener noreferrer">
            GitHub Portfolio
          </a>
        </div>
      </section>

      <section className="about-project" aria-labelledby="project-overview">
        <h2 id="project-overview">Project Overview</h2>
        <p>
          The Contoso RAG application blends deterministic data processing with generative AI to answer complex sales questions.
          Historical transactions from Contoso Retail are enriched, indexed, and served to a DeepSeek LLM, resulting in accurate
          and auditable insights accompanied by ready-to-visualise chart data.
        </p>
        <div className="about-grid">
          <div className="grid-card">
            <h3>Why RAG?</h3>
            <p>
              Retrieval-Augmented Generation grounds large language models with your data. By retrieving curated sales facts prior to
              generation, the system delivers consistent answers, cites original records, and keeps hallucinations in check.
            </p>
          </div>
          <div className="grid-card">
            <h3>Key Capabilities</h3>
            <ul>
              <li>Natural language questions over 3 years of Contoso sales history</li>
              <li>Forecasting prompts that quantify confidence and visualise trends</li>
              <li>Markdown- and JSON-aware response parser that guarantees chart rendering</li>
              <li>GitHub Actions and Azure Container Apps for hands-free deployments</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="about-architecture" aria-labelledby="architecture-heading">
        <h2 id="architecture-heading">Current Cloud Architecture</h2>
        <p>
          The platform is fully containerised and hosted on Azure. The design keeps infrastructure lean while staying production ready.
          Each component is independently deployable, with secrets managed via Container Apps and observability handled through Azure Monitor.
        </p>
        <div className="architecture-grid">
          <div className="arch-card">
            <h3>React Frontend</h3>
            <p>Vercel-hosted SPA with Chart.js visualizations and responsive UI</p>
          </div>
          <div className="arch-card">
            <h3>.NET 8 Web API</h3>
            <p>Azure Container Apps (Port 7048) orchestrating RAG pipeline and search queries</p>
          </div>
          <div className="arch-card">
            <h3>Azure AI Search</h3>
            <p>Hybrid vector + keyword index over enriched Contoso sales documents</p>
          </div>
          <div className="arch-card">
            <h3>DeepSeek LLM</h3>
            <p>Direct API integration with strict JSON contract for chart data</p>
          </div>
          <div className="arch-card">
            <h3>PostgreSQL DB</h3>
            <p>Azure-hosted database storing ETL staging and historical fact tables</p>
          </div>
        </div>
      </section>

      <section className="about-dataflow" aria-labelledby="dataflow-heading">
        <h2 id="dataflow-heading">RAG Dataflow</h2>
        <ol>
          <li><strong>Ask:</strong> User submits a sales or forecasting question from the React UI.</li>
          <li><strong>Retrieve:</strong> Azure AI Search returns enriched Contoso records ranked by semantic + keyword relevance.</li>
          <li><strong>Augment:</strong> .NET RAG service stitches context (prompt + records + structured instructions).</li>
          <li><strong>Generate:</strong> DeepSeek produces a strict JSON payload with narrative, chart metadata, and confidence.</li>
          <li><strong>Render:</strong> Response parser sanitises the JSON, validates chart values, and feeds Chart.js for visual insight.</li>
        </ol>
      </section>

      <section className="about-tech" aria-labelledby="tech-heading">
        <h2 id="tech-heading">Technology Stack</h2>
        <div className="tech-grid">
          <div>
            <h3>Frontend</h3>
            <ul>
              <li>React 18 with React Router</li>
              <li>Chart.js + react-chartjs-2</li>
              <li>Vercel hosting &amp; preview environments</li>
            </ul>
          </div>
          <div>
            <h3>Backend</h3>
            <ul>
              <li>.NET 8 Minimal API</li>
              <li>Azure Container Apps (GitHub Container Registry)</li>
              <li>ETL jobs producing enriched dimensional models</li>
            </ul>
          </div>
          <div>
            <h3>AI &amp; Data</h3>
            <ul>
              <li>Azure AI Search hybrid vector index</li>
              <li>DeepSeek LLM (direct API)</li>
              <li>Azure Database for PostgreSQL</li>
            </ul>
          </div>
        </div>
      </section>
    </main>
  );
}

export default AboutPage;
