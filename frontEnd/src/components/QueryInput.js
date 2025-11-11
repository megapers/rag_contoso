import React, { useState } from 'react';
import './QueryInput.css';

function QueryInput({ onSubmit, loading }) {
  const [question, setQuestion] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (question.trim() && !loading) {
      onSubmit(question.trim());
    }
  };

  const sampleQuestions = [
    "What were the total sales in November 2007?",
    "Show me the top 5 products by profit margin",
    "Compare sales by manufacturer",
    "Based on historical trends, what are predicted sales for 2010?",
    "What is the sales forecast for next year?",
    "Predict future sales based on the past 3 years"
  ];

  const handleSampleClick = (sample) => {
    setQuestion(sample);
  };

  return (
    <div className="query-input-container">
      <form onSubmit={handleSubmit} className="query-form">
        <div className="input-wrapper">
          <textarea
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ask a question about sales data... (e.g., 'What were the total sales in November 2007?')"
            className="query-textarea"
            rows="3"
            disabled={loading}
          />
        </div>
        <button 
          type="submit" 
          className="submit-button"
          disabled={!question.trim() || loading}
        >
          {loading ? 'Processing...' : '🔍 Ask Question'}
        </button>
      </form>

      <div className="sample-questions">
        <p className="sample-label">Sample questions:</p>
        <div className="sample-buttons">
          {sampleQuestions.map((sample, index) => (
            <button
              key={index}
              onClick={() => handleSampleClick(sample)}
              className="sample-button"
              disabled={loading}
            >
              {sample}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

export default QueryInput;
