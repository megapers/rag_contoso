import React, { useState } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
} from 'chart.js';
import { Bar, Line, Pie } from 'react-chartjs-2';
import './ChartDisplay.css';

// Register ChartJS components
ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
);

function ChartDisplay({ chartData }) {
  // Move useState before any early returns
  const { chartType: initialChartType = 'bar', title = 'Chart', labels = [], values = [] } = chartData || {};
  const [selectedChartType, setSelectedChartType] = useState(initialChartType.toLowerCase());

  if (!chartData || !chartData.labels || !chartData.values) {
    return null;
  }

  // Prepare data for Chart.js
  const data = {
    labels: labels,
    datasets: [
      {
        label: title,
        data: values,
        backgroundColor: selectedChartType === 'pie' ? [
          'rgba(102, 126, 234, 0.8)',
          'rgba(118, 75, 162, 0.8)',
          'rgba(237, 100, 166, 0.8)',
          'rgba(255, 154, 158, 0.8)',
          'rgba(255, 183, 178, 0.8)',
          'rgba(130, 177, 255, 0.8)',
        ] : 'rgba(102, 126, 234, 0.8)',
        borderColor: selectedChartType === 'pie' ? [
          'rgba(102, 126, 234, 1)',
          'rgba(118, 75, 162, 1)',
          'rgba(237, 100, 166, 1)',
          'rgba(255, 154, 158, 1)',
          'rgba(255, 183, 178, 1)',
          'rgba(130, 177, 255, 1)',
        ] : 'rgba(102, 126, 234, 1)',
        borderWidth: 2,
        tension: 0.4, // for line charts
      },
    ],
  };

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          font: {
            size: 12,
            family: '-apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto"',
          },
        },
      },
      title: {
        display: true,
        text: title,
        font: {
          size: 16,
          weight: 'bold',
          family: '-apple-system, BlinkMacSystemFont, "Segoe UI", "Roboto"',
        },
      },
      tooltip: {
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        padding: 12,
        titleFont: {
          size: 14,
        },
        bodyFont: {
          size: 13,
        },
      },
    },
    scales: selectedChartType !== 'pie' ? {
      y: {
        beginAtZero: true,
        grid: {
          color: 'rgba(0, 0, 0, 0.05)',
        },
        ticks: {
          font: {
            size: 11,
          },
        },
      },
      x: {
        grid: {
          display: false,
        },
        ticks: {
          font: {
            size: 11,
          },
          maxRotation: 45,
          minRotation: 0,
        },
      },
    } : undefined,
  };

  const renderChart = () => {
    switch (selectedChartType) {
      case 'line':
        return <Line data={data} options={options} />;
      case 'pie':
        return <Pie data={data} options={options} />;
      case 'bar':
      default:
        return <Bar data={data} options={options} />;
    }
  };

  const chartTypes = [
    { value: 'bar', label: 'Bar', icon: '📊' },
    { value: 'line', label: 'Line', icon: '📈' },
    { value: 'pie', label: 'Pie', icon: '🥧' }
  ];

  return (
    <div className="chart-display-container">
      <div className="chart-header">
        <h2>📈 Visual Insights</h2>
        <div className="chart-controls">
          <div className="chart-type-selector">
            {chartTypes.map(type => (
              <button
                key={type.value}
                className={`chart-type-btn ${selectedChartType === type.value ? 'active' : ''}`}
                onClick={() => setSelectedChartType(type.value)}
                title={`Switch to ${type.label} chart`}
              >
                <span className="chart-icon">{type.icon}</span>
                <span className="chart-label">{type.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>
      <div className="chart-wrapper">
        {renderChart()}
      </div>
    </div>
  );
}

export default ChartDisplay;
