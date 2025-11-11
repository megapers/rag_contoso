# 🚀 Getting Started with RAG Sales Analytics

## Overview

This is a full-stack RAG (Retrieval-Augmented Generation) application that allows users to query sales data using natural language and receive AI-powered insights with visual charts.

**Architecture:**
- **Backend**: .NET 8 Web API with Azure AI Search and LLM integration (Deepseek/OpenAI compatible)
- **Frontend**: React 18 with Chart.js for visualizations

---

## 📋 Quick Start

### Option 1: Start Both Applications Together

```powershell
# From the ETL directory
.\start.ps1
```

This will:
- Start the backend API at `https://localhost:7048`
- Start the frontend at `http://localhost:3000`
- Install frontend dependencies if needed

### Option 2: Start Individually

**Backend:**
```powershell
cd backEnd\ProductSales
dotnet run
```

**Frontend:**
```powershell
cd frontEnd
npm install    # First time only
npm start
```

---

## 🎯 How It Works

### User Flow

1. **User enters a question** (e.g., "What were total sales in November 2007?")
2. **Frontend sends query** to backend API via `/api/rag/query`
3. **Backend processes**:
   - Searches Azure AI Search for relevant sales data
   - Sends context + question to LLM API
   - LLM generates both text answer and chart data
4. **Frontend displays**:
   - Text answer in the result area
   - Interactive chart visualization (Bar/Line/Pie)

### Data Flow

```
React Frontend (Port 3000)
    ↓ HTTP POST
Backend API (Port 7048)
    ↓
Azure AI Search (Vector/Keyword Search)
    ↓
LLM API (Chat Completion)
    ↓
Response { answer: string, chartData: {...} }
    ↓
Frontend (Display + Chart.js Rendering)
```

---

## 📁 Project Structure

```
ETL/
├── start.ps1                      # Start both apps
├── start-frontend.ps1             # Start frontend only
├── README.md                      # Main documentation
│
├── backEnd/
│   └── ProductSales/
│       ├── Program.cs             # ✅ CORS configured
│       ├── Endpoints/
│       │   └── RagEndpoints.cs    # API endpoints
        ├── Services/
        │   ├── RagService.cs      # Core RAG logic
        │   ├── AzureSearchService.cs
        │   └── LlmApiClient.cs
│       └── Models/
│           └── DTOs/
│               └── ProductSalesEnriched.cs
│
└── frontEnd/
    ├── package.json
    ├── .env                       # API URL config
    ├── README.md                  # Frontend docs
    └── src/
        ├── App.js                 # Main app
        ├── components/
        │   ├── QueryInput.js      # Question input
        │   ├── ResultDisplay.js   # Text results
        │   └── ChartDisplay.js    # Chart visualization
        └── services/
            └── api.js             # Backend integration
```

---

## 🔧 Configuration

### Backend CORS (Already Configured ✅)

The backend `Program.cs` now includes:
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowReactApp",
        policy =>
        {
            policy.WithOrigins("http://localhost:3000", "http://localhost:3001")
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        });
});

// And in middleware:
app.UseCors("AllowReactApp");
```

### Frontend API Configuration

File: `frontEnd/.env`
```
REACT_APP_API_URL=https://localhost:7048
```

---

## 🎨 Frontend Components

### 1. **QueryInput Component**
- Text area for natural language questions
- Sample question buttons
- Submit button with loading state

### 2. **ResultDisplay Component**
- Shows AI-generated text answer
- Displays token usage badge
- Formatted with line breaks

### 3. **ChartDisplay Component**
- Dynamically renders charts based on `chartData.chartType`
- Supports: Bar, Line, Pie charts
- Responsive and interactive
- Uses Chart.js library

---

## 📊 API Response Format

### Successful Response

```json
{
  "answer": "In November 2007, the total sales were...",
  "chartData": {
    "chartType": "bar",
    "title": "Sales by Product",
    "labels": ["Product A", "Product B", "Product C"],
    "values": [12500, 8900, 15200]
  },
  "success": true,
  "sourceDocuments": [...],
  "tokensUsed": 450
}
```

### Chart Types
- `"bar"` - Bar chart (default)
- `"line"` - Line chart
- `"pie"` - Pie chart

---

## 🧪 Testing the Application

### Sample Questions to Try

1. **Time-based queries:**
   - "What were the total sales in November 2007?"
   - "Show me sales trends for 2007"

2. **Product analysis:**
   - "What are the top 5 products by profit margin?"
   - "Compare sales by manufacturer"

3. **Aggregations:**
   - "What is the average discount amount?"
   - "Show total revenue by brand"

4. **Specific products:**
   - "How did A. Datum cameras perform?"
   - "What's the profit margin on electronics?"

---

## 🐛 Troubleshooting

### Frontend Can't Connect to Backend

**Symptoms:** "Unable to connect to the server" error

**Solutions:**
1. Verify backend is running: `https://localhost:7048/swagger`
2. Check `.env` file has correct URL
3. Ensure CORS is enabled in `Program.cs` ✅ (already done)
4. Trust the development SSL certificate

### Charts Not Displaying

**Symptoms:** Answer shows but no chart

**Solutions:**
1. Check backend response includes `chartData` object
2. Verify `chartData` has required fields: `chartType`, `title`, `labels`, `values`
3. Check browser console for errors

### "HTTPS certificate is not trusted"

**Solution:**
```powershell
dotnet dev-certs https --trust
```

---

## 🔍 Key Files Modified

### Backend Changes

**File:** `backEnd/ProductSales/Program.cs`
- ✅ Added CORS policy for React app
- ✅ Enabled CORS middleware
- ✅ Allows origins: `http://localhost:3000`, `http://localhost:3001`

---

## 📦 Technologies Used

### Backend
- **.NET 8** - Web API framework
- **Azure AI Search** - Vector and semantic search
- **LLM API** - AI for generating insights (Deepseek, OpenAI compatible)
- **Entity Framework Core** - Database access
- **Swagger/OpenAPI** - API documentation

### Frontend
- **React 18** - UI framework
- **Chart.js** - Chart library
- **react-chartjs-2** - React wrapper for Chart.js
- **Axios** - HTTP client
- **CSS3** - Styling with gradients and animations

---

## 🎓 Architecture Highlights

### RAG Pipeline

1. **Retrieval:** Azure AI Search finds relevant sales documents
2. **Augmentation:** Context is added to the user's question
3. **Generation:** LLM generates structured response with both text and chart data

### Why This Works

- **Semantic Search:** Finds relevant data even without exact keywords
- **Context-Aware:** LLM understands the sales domain through enriched context
- **Structured Output:** LLM returns JSON with separate answer and chart data
- **Visual Insights:** Chart.js renders data for easy comprehension

---

## 🚀 Next Steps

### Enhancements You Could Add

1. **Multiple Charts:** Support multiple visualizations per query
2. **Export Data:** Download chart data as CSV/Excel
3. **History:** Save previous queries and results
4. **Authentication:** Add user login and saved preferences
5. **Real-time Updates:** WebSocket for live data updates
6. **Custom Filters:** Date ranges, product categories, etc.

---

## 📝 Notes

- Backend must be running before frontend
- First frontend start will install dependencies (may take 1-2 minutes)
- Backend uses HTTPS (port 7048), frontend uses HTTP (port 3000)
- Sample data is from Contoso Retail dataset (2007-2009)

---

## 🎉 You're All Set!

Run `.\start.ps1` and start querying your sales data! 🚀
