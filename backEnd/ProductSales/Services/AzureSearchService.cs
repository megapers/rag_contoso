using Azure;
using Azure.Search.Documents;
using Azure.Search.Documents.Indexes;
using Azure.Search.Documents.Indexes.Models;
using Azure.Search.Documents.Models;
using ProductSales.Models.DTOs;

namespace ProductSales.Services;

public interface IAzureSearchService
{
    Task<bool> CreateOrUpdateIndexAsync();
    Task<bool> IndexDocumentsAsync(IEnumerable<ProductSalesEnriched> documents);
    Task<SearchResults<ProductSalesEnriched>> SearchAsync(string query, int top = 5, string? filter = null);
    Task<SearchResults<ProductSalesEnriched>> HybridSearchAsync(string query, ReadOnlyMemory<float>? queryVector = null, int top = 5, string? filter = null);
    Task<bool> DeleteIndexAsync();
}

public class AzureSearchService : IAzureSearchService
{
    private readonly SearchIndexClient _indexClient;
    private readonly SearchClient _searchClient;
    private readonly string _indexName;
    private readonly ILogger<AzureSearchService> _logger;

    public AzureSearchService(IConfiguration configuration, ILogger<AzureSearchService> logger)
    {
        _logger = logger;
        
        var endpoint = configuration["AzureSearch:ServiceEndpoint"] 
            ?? throw new InvalidOperationException("Azure Search ServiceEndpoint not configured");
        var adminKey = configuration["AzureSearch:AdminKey"] 
            ?? throw new InvalidOperationException("Azure Search AdminKey not configured");
        _indexName = configuration["AzureSearch:IndexName"] ?? "product-sales-index";

        var credential = new AzureKeyCredential(adminKey);
        _indexClient = new SearchIndexClient(new Uri(endpoint), credential);
        _searchClient = _indexClient.GetSearchClient(_indexName);
    }

    public async Task<bool> CreateOrUpdateIndexAsync()
    {
        try
        {
            _logger.LogInformation("Creating or updating search index: {IndexName}", _indexName);

            var fieldBuilder = new FieldBuilder();
            var searchFields = fieldBuilder.Build(typeof(ProductSalesEnriched));

            // Configure vector search with HNSW algorithm
            var vectorSearch = new VectorSearch();
            vectorSearch.Profiles.Add(new VectorSearchProfile("vector-profile", "hnsw-config"));
            vectorSearch.Algorithms.Add(new HnswAlgorithmConfiguration("hnsw-config")
            {
                Parameters = new HnswParameters
                {
                    Metric = VectorSearchAlgorithmMetric.Cosine,
                    M = 4,
                    EfConstruction = 400,
                    EfSearch = 500
                }
            });

            var definition = new SearchIndex(_indexName, searchFields)
            {
                VectorSearch = vectorSearch
            };

            await _indexClient.CreateOrUpdateIndexAsync(definition);
            _logger.LogInformation("Search index created/updated successfully with vector search support");
            
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create/update search index");
            return false;
        }
    }

    public async Task<bool> IndexDocumentsAsync(IEnumerable<ProductSalesEnriched> documents)
    {
        try
        {
            var documentsList = documents.ToList();
            var totalDocuments = documentsList.Count;
            _logger.LogInformation("Indexing {Count} documents in batches...", totalDocuments);

            const int batchSize = 1000; // Azure AI Search limit
            var totalBatches = (int)Math.Ceiling(totalDocuments / (double)batchSize);
            var successfullyIndexed = 0;
            var failedBatches = 0;

            for (int i = 0; i < totalBatches; i++)
            {
                var batch = documentsList.Skip(i * batchSize).Take(batchSize).ToList();
                
                try
                {
                    var indexBatch = IndexDocumentsBatch.Upload(batch);
                    var result = await _searchClient.IndexDocumentsAsync(indexBatch);
                    
                    successfullyIndexed += result.Value.Results.Count;
                    
                    _logger.LogInformation(
                        "Batch {Current}/{Total}: Indexed {Count} documents. Total progress: {Progress}/{Total}",
                        i + 1, totalBatches, result.Value.Results.Count, successfullyIndexed, totalDocuments);
                    
                    // Small delay to avoid throttling
                    if (i < totalBatches - 1)
                    {
                        await Task.Delay(100);
                    }
                }
                catch (Exception batchEx)
                {
                    failedBatches++;
                    _logger.LogError(batchEx, "Failed to index batch {Current}/{Total}", i + 1, totalBatches);
                    
                    // Continue with next batch even if one fails
                    if (failedBatches > 10)
                    {
                        _logger.LogError("Too many failed batches ({Count}), stopping indexing", failedBatches);
                        return false;
                    }
                }
            }

            _logger.LogInformation(
                "Indexing complete. Successfully indexed {Success}/{Total} documents. Failed batches: {Failed}",
                successfullyIndexed, totalDocuments, failedBatches);
            
            return failedBatches == 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to index documents");
            return false;
        }
    }

    public async Task<SearchResults<ProductSalesEnriched>> SearchAsync(string query, int top = 5, string? filter = null)
    {
        try
        {
            _logger.LogInformation("Searching for: {Query} with filter: {Filter}", query, filter ?? "none");

            // Using BM25 full-text search (compatible with free tier)
            var options = new SearchOptions
            {
                Size = top,
                Select = { "*" },
                QueryType = SearchQueryType.Full // Full-text search with BM25 ranking
            };

            if (!string.IsNullOrEmpty(filter))
            {
                options.Filter = filter;
            }

            var results = await _searchClient.SearchAsync<ProductSalesEnriched>(query, options);
            
            return results.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Search failed for query: {Query}", query);
            throw;
        }
    }

    public async Task<SearchResults<ProductSalesEnriched>> HybridSearchAsync(
        string query, 
        ReadOnlyMemory<float>? queryVector = null, 
        int top = 5, 
        string? filter = null)
    {
        try
        {
            _logger.LogInformation("Hybrid search for: {Query} (vector: {HasVector})", query, queryVector.HasValue);

            var options = new SearchOptions
            {
                Size = top,
                Select = { "*" },
                QueryType = SearchQueryType.Full
            };

            if (!string.IsNullOrEmpty(filter))
            {
                options.Filter = filter;
            }

            // Add vector search if embedding is provided
            if (queryVector.HasValue && queryVector.Value.Length > 0)
            {
                var vectorQuery = new VectorizedQuery(queryVector.Value)
                {
                    KNearestNeighborsCount = top,
                    Fields = { "Embedding" }
                };
                options.VectorSearch = new VectorSearchOptions
                {
                    Queries = { vectorQuery }
                };

                _logger.LogInformation("Using hybrid search (BM25 + vector similarity)");
            }
            else
            {
                _logger.LogInformation("Vector not provided, falling back to BM25 only");
            }

            var results = await _searchClient.SearchAsync<ProductSalesEnriched>(query, options);
            
            return results.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Hybrid search failed for query: {Query}", query);
            throw;
        }
    }

    public async Task<bool> DeleteIndexAsync()
    {
        try
        {
            _logger.LogInformation("Deleting search index: {IndexName}", _indexName);
            await _indexClient.DeleteIndexAsync(_indexName);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete search index");
            return false;
        }
    }
}
