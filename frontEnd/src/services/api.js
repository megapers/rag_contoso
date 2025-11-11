import axios from 'axios';

// Configure the base URL for the API
// Change this to match your backend URL
// Uses HTTP by default for development (http://localhost:5003)
// For HTTPS, use: https://localhost:7048
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5003';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * Query the RAG system with a question
 * @param {string} question - The question to ask
 * @returns {Promise} Response containing answer and chart data
 */
export const queryRAG = async (question) => {
  try {
    const response = await api.post('/api/rag/query', { question });
    return response.data;
  } catch (error) {
    if (error.response) {
      // Server responded with error status
      const status = error.response.status;
      const data = error.response.data;
      
      if (status === 400) {
        throw new Error(data.error || 'Invalid request');
      } else if (status === 500) {
        throw new Error(data.detail || data.title || 'Server error occurred');
      } else {
        throw new Error(data.error || data.title || `Server error (${status})`);
      }
    } else if (error.request) {
      // Request made but no response
      throw new Error('Unable to connect to the server. Please ensure the backend is running.');
    } else {
      // Something else happened
      throw new Error(error.message || 'An unexpected error occurred');
    }
  }
};

/**
 * Index data into Azure AI Search
 * @returns {Promise} Response indicating success or failure
 */
export const indexData = async () => {
  try {
    const response = await api.post('/api/rag/index');
    return response.data;
  } catch (error) {
    if (error.response) {
      throw new Error(error.response.data.error || 'Failed to index data');
    } else if (error.request) {
      throw new Error('Unable to connect to the server');
    } else {
      throw new Error(error.message || 'An unexpected error occurred');
    }
  }
};

/**
 * Check RAG service status
 * @returns {Promise} Status information
 */
export const checkStatus = async () => {
  try {
    const response = await api.get('/api/rag/status');
    return response.data;
  } catch (error) {
    if (error.response) {
      throw new Error(error.response.data.error || 'Failed to check status');
    } else if (error.request) {
      throw new Error('Unable to connect to the server');
    } else {
      throw new Error(error.message || 'An unexpected error occurred');
    }
  }
};

export default api;
