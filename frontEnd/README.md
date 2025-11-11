# RAG Frontend Application

A React-based frontend for the RAG (Retrieval-Augmented Generation) sales analytics system.

## Features

- 🔍 Natural language query interface
- 💡 AI-powered insights from sales data
- 📊 Dynamic chart visualization (Bar, Line, Pie charts)
- 🎨 Modern, responsive UI design

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- Backend API running (default: https://localhost:7048)

## Installation

```bash
# Install dependencies
npm install
```

## Configuration

The frontend connects to the backend API. By default, it uses `https://localhost:7048`.

To change the API URL, create a `.env` file in the `frontEnd` directory:

```
REACT_APP_API_URL=https://your-backend-url
```

## Running the Application

```bash
# Start development server
npm start
```

The application will open at `http://localhost:3000`

## Building for Production

```bash
# Create production build
npm run build
```

The build folder will contain the optimized production files.

## Project Structure

```
frontEnd/
├── public/
│   └── index.html
├── src/
│   ├── components/
│   │   ├── QueryInput.js       # Query input component
│   │   ├── ResultDisplay.js    # Text result display
│   │   └── ChartDisplay.js     # Chart visualization
│   ├── services/
│   │   └── api.js              # API integration
│   ├── App.js                  # Main app component
│   ├── App.css
│   ├── index.js
│   └── index.css
└── package.json
```

## Usage

1. Enter a question about sales data in the input area
2. Click "Ask Question" or press Enter
3. View the AI-generated answer in the text result area
4. See visual insights in the chart below (if applicable)

## Sample Questions

- "What were the total sales in November 2007?"
- "Show me the top 5 products by profit margin"
- "Compare sales by manufacturer"
- "What is the average discount amount?"

## Technologies Used

- React 18
- Chart.js with react-chartjs-2
- Axios for API calls
- CSS3 for styling
