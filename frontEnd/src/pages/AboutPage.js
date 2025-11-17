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
          <h3>1. Retrieval: Hybrid Search with BM25 + Vector Similarity</h3>
          <p>
            When you ask a question, the system employs <strong>hybrid search</strong>—combining traditional keyword matching with semantic vector similarity—to retrieve the most relevant sales records from <strong>Azure AI Search</strong>.
          </p>
          
          <h4>BM25 Keyword Search</h4>
          <p>
            The first component is <strong>BM25 (Best Match 25)</strong>, a probabilistic ranking algorithm that scores documents
            based on term frequency (TF) and inverse document frequency (IDF). This ensures that records matching your exact keywords—whether product names,
            dates, categories, or manufacturers—are surfaced with precision. BM25 excels at finding documents with explicit word matches.
          </p>
          
          <h4>Vector Semantic Search</h4>
          <p>
            The second component uses <strong>dense vector embeddings</strong> to capture semantic meaning. Every sales document is transformed into
            a 384-dimensional vector using the <strong>all-MiniLM-L6-v2</strong> sentence transformer model—a compact BERT-based encoder optimized
            for semantic similarity tasks. This ONNX model runs locally in the .NET backend using <code>Microsoft.ML.OnnxRuntime</code>, generating
            embeddings with sub-second latency.
          </p>
          <p>
            When you submit a query, the system generates an embedding for your question using the same model, then performs a vector similarity search
            using <strong>cosine distance</strong> in Azure AI Search. This retrieves documents that are semantically related to your question—even if
            they don't share exact keywords. For example, asking "best performing products" will match documents about "top-selling items" or "highest revenue".
          </p>
          
          <h4>HNSW Vector Index</h4>
          <p>
            The vector search is powered by <strong>HNSW (Hierarchical Navigable Small World)</strong>, a graph-based algorithm that enables fast
            approximate nearest neighbor search. Configured with <code>M=4</code> (graph connections per node), <code>efConstruction=400</code> (build-time quality),
            and <code>efSearch=500</code> (query-time recall), the index delivers sub-millisecond vector lookups even as the corpus scales.
          </p>
          
          <h4>Hybrid Fusion</h4>
          <p>
            Azure AI Search automatically combines BM25 scores and vector similarity scores using <strong>Reciprocal Rank Fusion (RRF)</strong>.
            This technique merges the two result sets by ranking position rather than raw scores, ensuring balanced contributions from both keyword
            and semantic signals. The result is a unified ranked list where both exact matches and conceptually similar documents appear at the top.
          </p>
          
          <p>
            The search index is built from <strong>enriched sales documents</strong> that combine transactional data (sales amount, quantity, date)
            with product metadata (manufacturer, brand, color, class). Each document includes both searchable text fields for BM25 and a 384-dimensional
            embedding vector for semantic search.
          </p>
          
          <p className="technical-note">
            <strong>Technical details:</strong> The index schema is defined dynamically using the <code>FieldBuilder</code> in the .NET SDK.
            Documents are indexed in batches of 1,000 to respect Azure's throttling limits. The ONNX embedding model (86MB) is copied to the build
            output directory and loaded once at startup. Tokenization uses BERT's WordPiece algorithm with a 30,522-token vocabulary, generating
            input_ids, attention_mask, and token_type_ids tensors for the ONNX inference session.
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
