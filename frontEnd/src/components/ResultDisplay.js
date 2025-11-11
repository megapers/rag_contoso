import React from 'react';
import './ResultDisplay.css';

function ResultDisplay({ answer, tokensUsed }) {
  // Detect if this is a predictive/forecast response
  const isPredictive = answer && (
    answer.toLowerCase().includes('predict') ||
    answer.toLowerCase().includes('forecast') ||
    answer.toLowerCase().includes('estimated') ||
    answer.toLowerCase().includes('projection')
  );

  return (
    <div className="result-display-container">
      <div className="result-header">
        <h2>{isPredictive ? '🔮 AI Forecast & Analysis' : '💡 AI Analysis'}</h2>
        <div className="result-badges">
          {isPredictive && (
            <span className="prediction-badge">
              📊 Predictive Analysis
            </span>
          )}
          {tokensUsed > 0 && (
            <span className="tokens-badge">
              {tokensUsed} tokens
            </span>
          )}
        </div>
      </div>
      {isPredictive && (
        <div className="prediction-notice">
          <strong>⚠️ Note:</strong> This is a forecast based on historical trends. 
          Predictions should be used as estimates only.
        </div>
      )}
      <div className="result-content">
        <p>{answer}</p>
      </div>
    </div>
  );
}

export default ResultDisplay;
