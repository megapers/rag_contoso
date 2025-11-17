# RAG Pipeline Explained: Step-by-Step

A complete walkthrough of how Retrieval-Augmented Generation works in the Contoso Sales Intelligence platform.

---

## 🎯 What is RAG?

**Retrieval-Augmented Generation (RAG)** is a technique that enhances Large Language Models (LLMs) by retrieving relevant information from your data before generating an answer. Instead of relying solely on the model's training data, RAG grounds responses in factual, up-to-date information from your domain.

**The Problem RAG Solves:**
- LLMs hallucinate when asked about specific domain data they weren't trained on
- Training custom models is expensive and time-consuming
- Data changes frequently, but retraining models is impractical

**RAG Solution:**
1. Store your data in a searchable index
2. Retrieve relevant documents for each question
3. Feed those documents to the LLM as context
4. Generate accurate, grounded answers

---

## 📊 The RAG Pipeline: Four Stages

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │             │     │             │     │             │
│  INDEXING   │────▶│  RETRIEVAL  │────▶│ AUGMENTATION│────▶│ GENERATION  │
│             │     │             │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
   Prepare Data       Find Relevant       Build Context      Generate Answer
```

---

## 1️⃣ INDEXING STAGE: Preparing Data for Search

**What Happens:** Raw sales data is transformed into searchable documents with embeddings.

### Step 1.1: ETL Pipeline (`EtlService`)
```
Raw Database → Enriched Documents
```

**Input:** PostgreSQL database with two tables:
- `FactSales`: Transaction data (date, quantity, amount, product key)
- `DimProduct`: Product metadata (name, manufacturer, brand, description)

**Process:**
```csharp
// EtlService.GetEnrichedDataAsync()
var enrichedData = from sales in factSales
                   join product in dimProducts 
                   on sales.ProductKey equals product.ProductKey
                   select new ProductSalesEnriched {
                       SalesKey = $"{sales.SalesKey}_{sales.DateKey:yyyyMMdd}",
                       ProductName = product.ProductName,
                       SalesAmount = sales.SalesAmount,
                       // ... 30+ fields combined
                   };
```

**Output:** Unified documents combining sales + product data
- Each document has ~30 fields (sales metrics + product attributes)
- A `SearchableText` field with human-readable summary

### Step 1.2: Embedding Generation (`EmbeddingService`)
```
Text → 384-dimensional Vector
```

**Model:** `all-MiniLM-L6-v2` (BERT-based sentence transformer)
- Format: ONNX (86MB file)
- Inference: Microsoft.ML.OnnxRuntime (CPU-based)
- Dimensions: 384 floats per document

**Process:**
```csharp
// For each document:
var searchableText = "Sale of WWI Laptop12 M0120 White by Wide World Importers...";

// 1. Tokenize with BERT WordPiece
var (inputIds, attentionMask, tokenTypeIds) = TokenizeText(searchableText);

// 2. Run ONNX inference
var outputs = session.Run(new[] {
    NamedOnnxValue.CreateFromTensor("input_ids", inputIds),
    NamedOnnxValue.CreateFromTensor("attention_mask", attentionMask),
    NamedOnnxValue.CreateFromTensor("token_type_ids", tokenTypeIds)
});

// 3. Mean pooling + normalization
var embedding = MeanPooling(outputs, attentionMask);
embedding = Normalize(embedding); // 384 floats
```

**Output:** Each document now has:
- All original fields
- `Embedding` property: `IReadOnlyList<float>` with 384 values

**Performance:** ~200ms per document (includes tokenization + inference)

### Step 1.3: Index Creation (`AzureSearchService`)
```
Documents → Azure AI Search Index
```

**Index Schema:**
```csharp
// AzureSearchService.CreateOrUpdateIndexAsync()
var definition = new SearchIndex("product-sales-index", searchFields) {
    VectorSearch = new VectorSearch {
        Profiles = [new VectorSearchProfile("vector-profile", "hnsw-config")],
        Algorithms = [new HnswAlgorithmConfiguration("hnsw-config") {
            Metric = VectorSearchAlgorithmMetric.Cosine,
            M = 4,                // Graph connections per node
            EfConstruction = 400, // Build-time quality
            EfSearch = 500        // Query-time recall
        }]
    }
};
```

**Fields Indexed:**
- **Searchable:** ProductName, Manufacturer, BrandName, ClassName, ColorName, SearchableText
- **Filterable:** DateKey, SalesAmount, ProductKey, Status
- **Sortable:** DateKey, SalesAmount, SalesQuantity
- **Vector:** Embedding (384-dim, HNSW algorithm)

**Batch Upload:**
```csharp
// Upload in batches of 1,000 (Azure limit)
const int batchSize = 1000;
for (int i = 0; i < totalBatches; i++) {
    var batch = documents.Skip(i * batchSize).Take(batchSize);
    await _searchClient.IndexDocumentsAsync(IndexDocumentsBatch.Upload(batch));
    await Task.Delay(100); // Avoid throttling
}
```

**Result:** Azure AI Search index with:
- 650 documents (in current deployment)
- Full-text search capability (BM25)
- Vector search capability (HNSW)

---

## 2️⃣ RETRIEVAL STAGE: Finding Relevant Documents

**What Happens:** When a user asks a question, the system finds the most relevant sales records using hybrid search.

### Step 2.1: Query Embedding (`EmbeddingService`)
```
User Question → 384-dimensional Vector
```

**Input:** User question (e.g., "Which products had highest sales in 2008?")

**Process:**
```csharp
// RagService.QueryAsync()
var queryEmbedding = _embeddingService.GetEmbedding(question);
// Returns: ReadOnlyMemory<float> with 384 dimensions
```

**Output:** Query vector for semantic search

### Step 2.2: Hybrid Search (`AzureSearchService`)
```
Question + Query Vector → Top Relevant Documents
```

**Two Search Methods Combined:**

#### A. BM25 Keyword Search (Lexical)
- **Algorithm:** Best Match 25 (probabilistic ranking)
- **How it works:**
  - Tokenizes query into words: ["products", "highest", "sales", "2008"]
  - Scores each document based on:
    - **TF (Term Frequency):** How often query terms appear in document
    - **IDF (Inverse Document Frequency):** How rare each term is across all documents
  - Formula: `score = IDF × (TF × (k1 + 1)) / (TF + k1 × (1 - b + b × docLength/avgDocLength))`
- **Strengths:** Exact matches, proper nouns, product codes

#### B. Vector Search (Semantic)
- **Algorithm:** HNSW (Hierarchical Navigable Small World graph)
- **How it works:**
  1. Compares query embedding to all document embeddings
  2. Uses **cosine similarity**: `similarity = dot(query, doc) / (||query|| × ||doc||)`
  3. HNSW navigates graph structure for fast approximate nearest neighbor search
  4. Returns top K most similar documents
- **Strengths:** Semantic meaning, synonyms, paraphrases

#### C. Reciprocal Rank Fusion (RRF)
Azure AI Search automatically combines results:
```
RRF_score = Σ (1 / (rank_in_result_set + 60))
```
- Each search method ranks documents independently
- RRF merges rankings by position (not raw scores)
- Ensures both keyword and semantic signals contribute equally

**Code:**
```csharp
// AzureSearchService.HybridSearchAsync()
var options = new SearchOptions {
    Size = 5,  // Top 5 documents
    QueryType = SearchQueryType.Full  // BM25 enabled
};

// Add vector search
var vectorQuery = new VectorizedQuery(queryEmbedding) {
    KNearestNeighborsCount = 5,
    Fields = { "Embedding" }
};
options.VectorSearch = new VectorSearchOptions {
    Queries = { vectorQuery }
};

var results = await _searchClient.SearchAsync<ProductSalesEnriched>(query, options);
```

**Output:** Top 5-10 most relevant documents with relevance scores

---

## 3️⃣ AUGMENTATION STAGE: Building Context for LLM

**What Happens:** Retrieved documents are processed and formatted into structured context.

### Step 3.1: Re-ranking (`RagService.ReRankDocuments`)
```
Search Results → Ranked & Deduplicated Documents
```

**Heuristics Applied:**
1. **Deduplication:** Remove duplicate products/transactions
2. **Date relevance:** Boost recent transactions
3. **Sales magnitude:** Prioritize high-value transactions
4. **Match quality:** Keep highest-scoring results

### Step 3.2: Aggregation (`RagService`)
```
Individual Documents → Aggregated Insights
```

**For Standard Queries:**
```csharp
// Group by product and aggregate
var aggregated = documents
    .GroupBy(d => d.ProductKey)
    .Select(g => new {
        ProductName = g.First().ProductName,
        TotalSales = g.Sum(d => d.NetSalesAmount),
        TransactionCount = g.Count(),
        AvgUnitPrice = g.Average(d => d.UnitPrice)
    })
    .OrderByDescending(x => x.TotalSales)
    .Take(10);
```

**For Forecasting Queries:**
```csharp
// Build time-series data
var timeSeries = documents
    .GroupBy(d => d.DateKey.Year)
    .Select(g => new {
        Year = g.Key,
        TotalSales = g.Sum(d => d.SalesAmount),
        GrowthRate = CalculateYoYGrowth(...)
    })
    .OrderBy(x => x.Year);
```

### Step 3.3: Context Formatting
```
Aggregated Data → Plain Text Context
```

**Example Context:**
```
Based on the following historical sales data from 2007-2009:

Product Sales Summary:
1. WWI Laptop12 M0120 White (Wide World Importers)
   - Total Net Sales: $8,731.26
   - Transaction Count: 1
   - Category: Regular, Color: White
   
2. Fabrikam Budget Moviemaker (Fabrikam, Inc.)
   - Total Net Sales: $4,110.00
   - Transaction Count: 1
   - Category: Regular, Color: White

Time Period: 2007-01-05 to 2009-10-16
Total Documents Analyzed: 5
```

---

## 4️⃣ GENERATION STAGE: LLM Creates Answer

**What Happens:** The context + question are sent to DeepSeek LLM for answer generation.

### Step 4.1: Prompt Engineering (`RagService.BuildPrompt`)
```
Context + Question → Structured Prompt
```

**Prompt Structure:**
```
SYSTEM:
You are a sales data analyst. Answer questions using ONLY the provided data.
Return JSON: { "answer": "...", "chartData": { "chartType": "bar", "title": "...", "labels": [...], "values": [...] } }

USER:
Context: [Aggregated sales data here]

Question: Which products had highest sales in 2008?

Requirements:
- Cite specific numbers
- Sort data consistently
- Round to 2 decimals
- Provide chart visualization
```

### Step 4.2: LLM Call (`PerplexityApiClient`)
```
Prompt → DeepSeek API → JSON Response
```

**API Configuration:**
```csharp
var request = new {
    model = "deepseek-chat",
    messages = new[] {
        new { role = "system", content = systemPrompt },
        new { role = "user", content = userPrompt }
    },
    temperature = 0.1,  // Low temperature = more deterministic
    max_tokens = 2000
};

var response = await _httpClient.PostAsJsonAsync(_apiBaseUrl, request);
```

**LLM Output (JSON):**
```json
{
  "answer": "Based on the sales data from March to December 2008, the products with highest sales are: 1) Fabrikam Independent Filmmaker with $15,000 in sales...",
  "chartData": {
    "chartType": "bar",
    "title": "Top Products by Sales (2008)",
    "labels": ["Fabrikam Independent Filmmaker", "WWI Laptop12", "Litware Chandelier"],
    "values": [15000.00, 8731.26, 2299.90]
  }
}
```

### Step 4.3: Response Parsing (`RagService`)
```
JSON String → Structured Response
```

**Parsing Logic:**
```csharp
// Handle various JSON formats from LLM
var jsonContent = llmResponse;

// Remove markdown code blocks if present
jsonContent = Regex.Replace(jsonContent, @"^```json\s*|\s*```$", "").Trim();

// Unescape if needed
if (jsonContent.Contains("\\\"")) {
    jsonContent = Regex.Unescape(jsonContent);
}

// Deserialize
var ragResponse = JsonSerializer.Deserialize<RagResponse>(jsonContent);

// Validate chart data
if (ragResponse.ChartData?.Labels?.Count != ragResponse.ChartData?.Values?.Count) {
    ragResponse.ChartData = null; // Invalid chart, clear it
}
```

**Final Response:**
```csharp
public class RagResponse {
    public string Answer { get; set; }              // Natural language answer
    public ChartData? ChartData { get; set; }       // Visualization metadata
    public bool Success { get; set; }               // Query success flag
    public List<object>? SourceDocuments { get; set; }  // Retrieved documents
    public int TokensUsed { get; set; }             // LLM usage tracking
}
```

---

## 🔧 Services Involved

### Backend Services (.NET 8)

| Service | Responsibility | Key Methods |
|---------|---------------|-------------|
| **EtlService** | Data extraction & enrichment | `GetEnrichedDataAsync()` - Joins FactSales + DimProduct |
| **EmbeddingService** | Vector generation | `GetEmbedding()` - ONNX inference with BERT tokenization |
| **AzureSearchService** | Index management & search | `CreateOrUpdateIndexAsync()`, `HybridSearchAsync()` |
| **RagService** | RAG orchestration | `QueryAsync()` - Coordinates entire pipeline |
| **PerplexityApiClient** | LLM communication | `SendChatAsync()` - DeepSeek API wrapper |

### External Services

| Service | Provider | Purpose |
|---------|----------|---------|
| **Azure AI Search** | Microsoft Azure | Document indexing, BM25, HNSW vector search |
| **PostgreSQL** | Azure Database | Raw sales data storage |
| **DeepSeek LLM** | DeepSeek | Answer generation with structured JSON output |

### Frontend (React 18)

| Component | Purpose |
|-----------|---------|
| **QueryPage** | User interface for questions |
| **Chart.js** | Visualizes chartData from RAG response |
| **axios** | HTTP client for API calls |

---

## 📈 Data Flow Summary

```
┌──────────────────────────────────────────────────────────────────────┐
│                         INDEXING (One-time)                          │
├──────────────────────────────────────────────────────────────────────┤
│  PostgreSQL → EtlService → EmbeddingService → AzureSearchService     │
│  (FactSales + DimProduct) → (Enrich) → (ONNX 384-dim) → (HNSW Index)│
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                      QUERY (Per User Question)                       │
├──────────────────────────────────────────────────────────────────────┤
│  1. User Question → EmbeddingService → Query Vector (384-dim)        │
│  2. Query Vector + Question → AzureSearchService → Hybrid Search     │
│     ├─ BM25: Keyword matching                                        │
│     ├─ Vector: Semantic similarity (HNSW)                            │
│     └─ RRF: Merge results                                            │
│  3. Top Documents → RagService → Aggregate & Format Context          │
│  4. Context + Question → PerplexityApiClient → DeepSeek LLM          │
│  5. LLM JSON Response → RagService → Parse & Validate                │
│  6. Structured Response → React Frontend → Display Answer + Chart    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🎓 Key Concepts Explained

### What is Chunking?
**Not used in this implementation.** Chunking splits large documents into smaller pieces (e.g., 512-token chunks) to fit LLM context windows. Our sales records are already small (~200 tokens each), so no chunking needed.

### Why Hybrid Search?
- **BM25 alone:** Misses synonyms ("laptop" vs "portable computer")
- **Vector search alone:** Misses exact product codes like "M0120"
- **Hybrid:** Best of both worlds—finds exact matches AND semantic relevance

### Why ONNX for Embeddings?
- **Self-contained:** No external API dependency (unlike OpenAI embeddings)
- **Fast:** ~200ms per document on CPU
- **Cost-effective:** No per-request charges
- **Offline-capable:** Works without internet

### Why DeepSeek LLM?
- **Structured output:** Reliable JSON responses with chart data
- **Cost-effective:** Cheaper than GPT-4 for similar quality
- **Fast inference:** 1-2 second response times

---

## 📊 Performance Metrics

| Metric | Value |
|--------|-------|
| Documents indexed | 650 sales records |
| Index size | ~45 MB (with embeddings) |
| Embedding generation | ~200ms per document |
| Indexing time | ~234 seconds for 650 docs |
| Hybrid search latency | 50-100ms |
| End-to-end query time | 2-4 seconds (including LLM) |
| HNSW recall@5 | ~95% (efSearch=500) |

---

## 🚀 Production Deployment

| Component | Platform | Configuration |
|-----------|----------|---------------|
| Frontend | Vercel | React SPA, auto-deploy from `main` |
| Backend API | Azure Container Apps | .NET 8, 0.25 CPU, 0.5 GB RAM |
| Docker Image | GitHub Container Registry | Auto-build via GitHub Actions |
| Search Index | Azure AI Search (Free Tier) | 50 MB limit, 3 indexes |
| Database | Azure Database for PostgreSQL | Flexible Server |

---

## 🔑 Key Takeaways

1. **RAG = Retrieval + Generation:** Documents ground the LLM in facts
2. **Hybrid Search > Single Method:** Combines keyword precision with semantic understanding
3. **Embeddings Enable Semantic Search:** 384-dim vectors capture meaning beyond keywords
4. **HNSW = Fast Vector Search:** Graph algorithm enables sub-second similarity search
5. **Structured Prompts = Reliable Output:** JSON schema enforcement guarantees chart data
6. **Batch Processing = Scalability:** Index 1000s of documents via batching

---

**Built by Timur Makimov**  
Source: [github.com/megapers/rag_contoso](https://github.com/megapers/rag_contoso)
