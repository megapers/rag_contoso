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
    "Which sales channels generated the most revenue?",
    "Compare sales by manufacturer",
    "Show me products with the highest sales amounts",
    "What are the sales trends by month in 2009?",
    "Which stores had the best performance?"
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
