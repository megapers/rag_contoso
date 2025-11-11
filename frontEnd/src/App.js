import React, { useState } from 'react';
import './App.css';
import QueryInput from './components/QueryInput';
import ResultDisplay from './components/ResultDisplay';
import ChartDisplay from './components/ChartDisplay';
import { queryRAG } from './services/api';

function App() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);

  const handleQuery = async (question) => {
    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await queryRAG(question);
      setResult(response);
    } catch (err) {
      setError(err.message || 'Failed to process query');
      console.error('Query error:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>📊 Sales Data Analytics RAG</h1>
        <p>Ask questions about sales data and get AI-powered insights</p>
      </header>

      <main className="App-main">
        <QueryInput onSubmit={handleQuery} loading={loading} />

        {loading && (
          <div className="loading-container">
            <div className="spinner"></div>
            <p>Analyzing your question...</p>
          </div>
        )}

        {error && (
          <div className="error-container">
            <h3>❌ Error</h3>
            <p>{error}</p>
          </div>
        )}

        {result && (
          <div className="results-container">
            <ResultDisplay answer={result.answer} tokensUsed={result.tokensUsed} />
            {result.chartData && result.chartData.labels && result.chartData.values && (
              <ChartDisplay 
                chartData={result.chartData} 
              />
            )}
            {!result.chartData && (
              <div className="no-chart-message">
                <p>💡 No chart data available for this query. The response is text-only.</p>
              </div>
            )}
          </div>
        )}
      </main>

      <footer className="App-footer">
        <p>Powered by Azure AI Search + RAG Pipeline</p>
      </footer>
    </div>
  );
}

export default App;
