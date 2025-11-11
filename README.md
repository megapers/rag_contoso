# 🚀 RAG Sales Analytics - Full Stack Application

[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react)](https://react.dev/)
[![Azure](https://img.shields.io/badge/Azure-AI_Search-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/en-us/products/ai-services/ai-search)

A production-ready RAG (Retrieval-Augmented Generation) application for intelligent sales data analytics. Ask questions in natural language and receive AI-powered insights with interactive visualizations.

## ✨ Features

- 🤖 **Natural Language Queries** - Ask questions in plain English about your sales data
- 📊 **Dynamic Visualizations** - Auto-generated charts (Bar, Line, Pie) with Chart.js
- 🎯 **Smart Chart Switching** - Toggle between chart types without re-querying
- 🔮 **Predictive Analytics** - Forecast future trends based on historical data
- 🔍 **Semantic Search** - Azure AI Search with vector and keyword search
- 🎨 **Modern UI** - Responsive React interface with gradient styling
- 🌐 **Provider-Agnostic LLM** - Supports Deepseek, OpenAI, Claude, or any OpenAI-compatible API
- 📈 **Reranking Algorithm** - Consistent results through intelligent document scoring

## 🏗️ Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  React Frontend │─────▶│  .NET 8 Web API  │─────▶│ Azure AI Search │
│   (Port 3000)   │      │   (Port 7048)    │      │  Vector Search  │
└─────────────────┘      └──────────────────┘      └─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │    LLM API      │
                         │ (Deepseek/etc)  │
                         └─────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  SQL Server DB  │
                         │ (Contoso Retail)│
                         └─────────────────┘
```

## 📁 Project Structure

```
ETL/
├── backEnd/
│   └── ProductSales/           # .NET 8 Web API
│       ├── Endpoints/          # RESTful API endpoints
│       ├── Services/           # Business logic & RAG pipeline
│       │   ├── RagService.cs           # Core RAG implementation
│       │   ├── AzureSearchService.cs   # Search integration
│       │   └── LlmApiClient.cs         # Generic LLM client
│       ├── Repositories/       # Data access layer
│       ├── Models/             # Entity & DTO models
│       └── Infra/              # Bicep infrastructure files
│
├── frontEnd/                   # React 18 SPA
│   ├── src/
│   │   ├── components/         # React components
│   │   │   ├── QueryInput.js       # Question input
│   │   │   ├── ResultDisplay.js    # AI answers
│   │   │   └── ChartDisplay.js     # Chart visualization
│   │   └── services/
│   │       └── api.js          # Backend integration
│   └── package.json
│
├── start.ps1                   # Quick start script
├── README.md                   # This file
└── GETTING_STARTED.md          # Detailed setup guide
```

## ⚡ Quick Start

### Option 1: One-Command Start (Recommended)

```powershell
# From the ETL directory
.\start.ps1
```

This script will:
- ✅ Start the .NET backend API (port 7048)
- ✅ Install frontend dependencies (if needed)
- ✅ Start the React development server (port 3000)
- ✅ Open browser automatically

### Option 2: Manual Start

**Terminal 1 - Backend:**
```powershell
cd backEnd\ProductSales
dotnet run
```

**Terminal 2 - Frontend:**
```powershell
cd frontEnd
npm install  # First time only
npm start
```

### First-Time Setup

#### ⚠️ Important: Secure Configuration

This project uses **local configuration files for secrets** that are **excluded from Git**. Never commit files containing API keys, passwords, or connection strings.

1. **Clone the repository**
   ```powershell
   git clone <your-repo-url>
   cd ETL
   ```

2. **Configure backend secrets** - Copy the example file and add your credentials:
   ```powershell
   cd backEnd\ProductSales
   cp appsettings.example.json appsettings.json
   ```
   
   Edit `appsettings.json` and replace:
   - `YOUR_SQL_USERNAME` and `YOUR_SQL_PASSWORD` - SQL Server credentials
   - `YOUR_SEARCH_SERVICE_NAME` - Azure AI Search service name
   - `YOUR_AZURE_SEARCH_ADMIN_KEY` - Azure AI Search admin key
   - `YOUR_LLM_API_KEY` - LLM API key (Deepseek, OpenAI, etc.)

   **🔒 Security Note:** `appsettings.json` is in `.gitignore` and will NOT be committed to Git.

3. **Configure frontend** - Copy the example and verify settings:
   ```powershell
   cd ..\..\frontEnd
   cp .env.example .env
   ```
   
   The default `.env` should have:
   ```env
   REACT_APP_API_URL=https://localhost:7048
   ```
   
   **🔒 Security Note:** `.env` is in `.gitignore` and will NOT be committed to Git.

4. **Run the application**
   ```powershell
   cd ..
   .\start.ps1
   ```

#### 🔐 Security Best Practices

- ✅ **Secrets are gitignored**: `appsettings.json`, `.env`, and all credential files are excluded
- ✅ **Example files provided**: `appsettings.example.json` and `.env.example` with placeholder values
- ✅ **No hardcoded secrets**: All sensitive data loaded from configuration
- ⚠️ **Never commit secrets**: Always use the example files as templates
- 🔑 **Use different keys**: Use separate API keys for development and production
- 🔒 **SSL in production**: Always use HTTPS for deployed applications
- 🌐 **CORS configured**: Backend only accepts requests from specified origins

📖 **For detailed security guidelines, see [SECURITY.md](SECURITY.md)**

## 🔧 Configuration

### Backend (`appsettings.json`)

**⚠️ This file contains secrets and is NOT committed to Git.**

Copy `appsettings.example.json` to `appsettings.json` and configure:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;Database=ContosoRetailDW;User Id=YOUR_USERNAME;Password=YOUR_PASSWORD;TrustServerCertificate=True;Encrypt=Mandatory;"
  },
  "AzureSearch": {
    "ServiceEndpoint": "https://your-service.search.windows.net",
    "AdminKey": "YOUR_ADMIN_KEY",
    "IndexName": "product-sales-index"
  },
  "LlmApi": {
    "BaseUrl": "https://api.deepseek.com",
    "ApiKey": "YOUR_API_KEY",
    "Model": "deepseek-chat"
  }
}
```

**Supported LLM Providers:**
- **Deepseek** (default): `https://api.deepseek.com` - Cost-effective, fast
- **OpenAI**: `https://api.openai.com/v1` - GPT-4, GPT-3.5-turbo
- **Azure OpenAI**: `https://your-resource.openai.azure.com` - Enterprise features
- **Any OpenAI-compatible API** - Custom endpoints

### Frontend (`.env`)

**⚠️ This file contains configuration and is NOT committed to Git.**

Copy `.env.example` to `.env`:

```env
REACT_APP_API_URL=https://localhost:7048
```

For production, update to your deployed backend URL.

## 📖 Usage Examples

Once both applications are running, navigate to `http://localhost:3000` and try these questions:

### Time-Based Queries
```
"What were the total sales in November 2007?"
"Show me monthly sales trends for 2008"
"Compare Q1 vs Q4 sales in 2009"
```

### Product Analysis
```
"What are the top 5 products by profit margin?"
"Show me sales by manufacturer"
"Which brands had the highest revenue?"
```

### Predictive Analytics
```
"Predict sales for 2010 based on historical trends"
"What will be the expected revenue growth?"
"Forecast next quarter's sales"
```

### Aggregations
```
"What is the average discount amount per product?"
"Show total revenue by category"
"Compare profitability across different product classes"
```

## 🎨 Features in Detail

### 1. Natural Language Processing
- Ask questions conversationally
- Automatic date extraction and filtering
- Context-aware query understanding

### 2. Smart Visualizations
- **Auto-detection**: System chooses appropriate chart type
- **Manual switching**: Toggle between Bar/Line/Pie without re-querying
- **Responsive design**: Charts adapt to screen size

### 3. Predictive Analytics
- Time-series trend analysis
- Year-over-year growth calculation
- Linear regression for forecasting
- Confidence levels and methodology explanations

### 4. Reranking for Consistency
- Relevance scoring based on keywords
- Deduplication of results
- Prioritization of high-value transactions

## 🛠️ Technology Stack

### Backend
| Technology | Purpose |
|------------|---------|
| .NET 8 | Web API framework |
| Entity Framework Core | ORM for SQL Server |
| Azure AI Search | Vector & semantic search |
| Generic LLM Client | OpenAI-compatible API integration |
| Minimal APIs | Lightweight endpoint routing |

### Frontend
| Technology | Purpose |
|------------|---------|
| React 18 | UI framework |
| Chart.js | Data visualization |
| Axios | HTTP client |
| CSS3 | Modern styling with gradients |

### Infrastructure
| Service | Purpose |
|---------|---------|
| Azure Container Apps | Backend hosting |
| Azure Static Web Apps | Frontend hosting |
| Azure AI Search | Semantic search (Free tier) |
| SQL Server | Database |
| Bicep | Infrastructure as Code |

## 🔌 API Reference

### RAG Endpoints

#### Query RAG System
```http
POST /api/rag/query
Content-Type: application/json

{
  "question": "What were total sales in November 2007?"
}
```

**Response:**
```json
{
  "answer": "In November 2007, the total sales were $1,234,567.89...",
  "chartData": {
    "chartType": "bar",
    "title": "Sales by Product",
    "labels": ["Product A", "Product B"],
    "values": [12500.50, 8900.25]
  },
  "success": true,
  "sourceDocuments": [...],
  "tokensUsed": 450
}
```

#### Index Data
```http
POST /api/rag/index
```
Triggers ETL pipeline and indexes data into Azure AI Search.

### ETL Endpoints

- `POST /api/etl/run` - Execute ETL pipeline
- `GET /api/etl/enriched-data` - Retrieve enriched sales data

### Data Endpoints

- `GET /api/sales` - Get sales transactions
- `GET /api/products` - Get product catalog

## 🐛 Troubleshooting

### Backend Won't Start

**Issue:** Port 7048 already in use
```powershell
# Find and stop process
Get-Process -Id (Get-NetTCPConnection -LocalPort 7048).OwningProcess | Stop-Process
```

**Issue:** Database connection fails
- Verify SQL Server is running
- Check connection string in `appsettings.json`
- Ensure firewall allows port 1433

### Frontend Connection Errors

**Issue:** "Unable to connect to server"
1. Confirm backend is running: `https://localhost:7048/swagger`
2. Check `.env` has correct `REACT_APP_API_URL`
3. Trust SSL certificate: `dotnet dev-certs https --trust`

**Issue:** CORS errors
- Backend already configured for `http://localhost:3000` and `http://localhost:3001`
- If using different port, update CORS policy in `Program.cs`

### Charts Not Displaying

**Issue:** Answer shows but no chart

Check:
1. Backend response includes `chartData` object
2. `chartData` has: `chartType`, `title`, `labels`, `values`
3. Console for JavaScript errors

### Out of Memory / Slow Performance

**Issue:** Large dataset processing
- Current limit: 3,000 records for demo
- Batched indexing: 1,000 documents per batch
- Adjust in `FactSalesRepository.cs` and `AzureSearchService.cs`

## 🚀 Deployment to Azure

### Prerequisites
- Azure CLI installed
- Azure subscription
- Resource group created

### Deploy with Bicep

```powershell
cd backEnd\ProductSales\Infra

# Login to Azure
az login

# Deploy infrastructure
.\deploy-ai-search.ps1 -ResourceGroupName "rg-rag-sales" -Location "eastus"

# Deploy backend (Container Apps)
# Deploy frontend (Static Web Apps)
# See Infra/README.md for detailed instructions
```

### Environment Variables for Production

**Backend (Azure Container Apps):**

Set these as environment variables or Key Vault references:

```bash
# Database
ConnectionStrings__DefaultConnection="Server=..."

# Azure AI Search
AzureSearch__ServiceEndpoint="https://..."
AzureSearch__AdminKey="***"
AzureSearch__IndexName="product-sales-index"

# LLM API
LlmApi__BaseUrl="https://api.deepseek.com"
LlmApi__ApiKey="***"
LlmApi__Model="deepseek-chat"
```

**🔐 Production Security Recommendations:**
- Use **Azure Key Vault** for secrets management
- Enable **Managed Identity** for Azure services
- Use **Azure Key Vault references** in Container Apps configuration
- Never hardcode secrets in Bicep/ARM templates
- Rotate API keys regularly
- Use separate keys for dev/staging/production

**Frontend (Static Web Apps):**
```bash
REACT_APP_API_URL="https://your-backend.azurecontainerapps.io"
```

Configure in Static Web Apps configuration or build pipeline.

## 📊 Dataset

**Contoso Retail Sales Dataset (2007-2009)**
- 3,000 transactions (demo optimized)
- Products with manufacturer, brand, category
- Sales metrics: quantity, price, discount, profit margin
- Date-based filtering support

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📝 Development Notes

### Adding New Features

**New API Endpoint:**
1. Create endpoint in `backEnd/ProductSales/Endpoints/`
2. Register in `Program.cs`
3. Add API call in `frontEnd/src/services/api.js`

**New Chart Type:**
1. Update `ChartDisplay.js` component
2. Add chart type to `renderChart()` switch
3. Register Chart.js elements if needed

### Code Quality
- Backend: Follow C# conventions, use async/await
- Frontend: Use React hooks, functional components
- Formatting: Prettier for JS/JSX, default for C#

## 📄 License

This project is for educational and demonstration purposes.

## 🙏 Acknowledgments

- Contoso Retail dataset from Microsoft
- Azure AI Search for semantic search capabilities
- Chart.js for visualization library
- React and .NET communities

---

**Built with ❤️ for intelligent data analytics**
