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
        <h2 id="dataflow-heading">RAG Pipeline Explained</h2>
        
        <div className="dataflow-step">
          <h3>1. Retrieval: Azure AI Search with BM25</h3>
          <p>
            When you ask a question, the system first retrieves the most relevant sales records using <strong>Azure AI Search</strong>.
            The search service uses <strong>BM25 (Best Match 25)</strong>, a probabilistic ranking algorithm that scores documents
            based on term frequency and inverse document frequency. This ensures that records matching your keywords—whether product names,
            dates, or categories—are surfaced with precision.
          </p>
          <p>
            The search index is built from <strong>enriched sales documents</strong> that combine transactional data (sales amount, quantity, date)
            with product metadata (manufacturer, brand, color, class). Azure AI Search supports hybrid queries combining full-text and filtered searches,
            allowing the pipeline to narrow results by date ranges or other dimensions before passing them to the LLM.
          </p>
          <p className="technical-note">
            <strong>Technical detail:</strong> The index schema is defined dynamically using the <code>FieldBuilder</code> in the .NET SDK,
            and documents are indexed in batches of 1,000 to respect Azure's throttling limits. The free tier supports full-text BM25 search
            without requiring vector embeddings.
          </p>
        </div>

        <div className="dataflow-step">
          <h3>2. Augmentation: Context Building</h3>
          <p>
            Retrieved documents are ranked by relevance score, deduplicated, and aggregated into structured context. For standard queries,
            the RAG service groups sales by product and computes totals, averages, and transaction counts. For predictive queries (e.g., forecasts),
            it builds time-series aggregations with year-over-year growth rates.
          </p>
          <p>
            This context—formatted as plain text with clear headings—is inserted into the LLM prompt alongside your original question and
            strict JSON formatting instructions. The prompt engineering ensures the LLM responds with both a natural language answer and
            structured chart data (labels, values, chart type).
          </p>
        </div>

        <div className="dataflow-step">
          <h3>3. Generation: DeepSeek LLM</h3>
          <p>
            The augmented prompt is sent to <strong>DeepSeek</strong> via its chat completions API. The LLM analyzes the context,
            interprets your question, and produces a JSON response containing:
          </p>
          <ul>
            <li><strong>Answer:</strong> A detailed narrative explanation with specific numbers and insights</li>
            <li><strong>ChartData:</strong> Structured visualization metadata (chart type, title, labels array, values array)</li>
          </ul>
          <p>
            The system prompt enforces consistency—instructing the model to always sort data the same way, round to two decimals, and return
            raw JSON without markdown wrappers. For forecasting queries, it explicitly asks for trend analysis, growth rate calculations,
            and confidence ranges.
          </p>
        </div>

        <div className="dataflow-step">
          <h3>4. Parsing & Rendering</h3>
          <p>
            The .NET RAG service parses the LLM's JSON response, handling edge cases like markdown code blocks or escaped strings (using
            <code>Regex.Unescape</code> for nested JSON). It validates the chart data structure, ensuring labels and values align, and
            makes chart fields nullable to gracefully handle text-only responses.
          </p>
          <p>
            Finally, the React frontend receives the validated response and renders the answer text alongside a Chart.js visualization
            (bar, line, or pie chart). If no chart data is available, it displays a friendly message instead of breaking the UI.
          </p>
        </div>
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
