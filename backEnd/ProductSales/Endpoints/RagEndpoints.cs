using ProductSales.Services;

namespace ProductSales.Endpoints;

public static class RagEndpoints
{
    public static void MapRagEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/rag")
            .WithTags("RAG Pipeline");

        group.MapPost("/query", async (RagQueryRequest request, IRagService ragService) =>
        {
            if (string.IsNullOrWhiteSpace(request.Question))
            {
                return Results.BadRequest(new { error = "Question is required" });
            }

            var response = await ragService.QueryAsync(request.Question);
            
            // Always return 200 OK with the response, even if no data found
            // Frontend can handle the Success flag to show appropriate message
            return Results.Ok(response);
        })
        .WithName("QueryRAG")
        .WithDescription("Query the RAG system with a natural language question about sales data")
        .WithOpenApi();

        group.MapPost("/index", async (IRagService ragService, int? limit) =>
        {
            var success = await ragService.IndexDataAsync(limit);
            
            if (success)
            {
                return Results.Ok(new 
                { 
                    success = true, 
                    message = $"Data indexed successfully in Azure AI Search{(limit.HasValue ? $" (limited to {limit} documents)" : "")}" 
                });
            }
            
            return Results.Problem("Failed to index data");
        })
        .WithName("IndexRAGData")
        .WithDescription("Index enriched sales data into Azure AI Search for RAG queries")
        .WithOpenApi();

        group.MapGet("/status", () =>
        {
            return Results.Ok(new
            {
                Status = "Ready",
                Message = "RAG service is ready to process queries",
                Timestamp = DateTime.UtcNow
            });
        })
        .WithName("GetRAGStatus")
        .WithDescription("Check the status of the RAG service")
        .WithOpenApi();

        group.MapPost("/test-embedding", (IEmbeddingService embeddingService, ILogger<Program> logger) =>
        {
            try
            {
                logger.LogInformation("Testing embedding generation...");
                var testText = "This is a test sentence for embedding generation.";
                var embedding = embeddingService.GetEmbedding(testText);
                
                return Results.Ok(new
                {
                    Success = true,
                    Message = "Embedding generated successfully",
                    EmbeddingDimensions = embedding.Length,
                    FirstFewValues = embedding.Take(5).ToArray()
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to generate test embedding");
                return Results.Problem($"Error: {ex.Message}\nStack: {ex.StackTrace}");
            }
        })
        .WithName("TestEmbedding")
        .WithDescription("Test embedding generation with a simple sentence")
        .WithOpenApi();

        group.MapPost("/test-azure-search", async (IAzureSearchService searchService, IEtlService etlService, ILogger<Program> logger) =>
        {
            try
            {
                logger.LogInformation("Testing Azure AI Search connection and document indexing...");
                
                // Step 1: Create index
                var indexCreated = await searchService.CreateOrUpdateIndexAsync();
                if (!indexCreated)
                {
                    return Results.Problem("Failed to create/update index");
                }
                
                // Step 2: Get one document with embedding
                var documents = await etlService.GetEnrichedDataAsync(1);
                var docsList = documents.ToList();
                
                if (docsList.Count == 0)
                {
                    return Results.Problem("No documents to index");
                }
                
                // Step 3: Try to index it
                var indexed = await searchService.IndexDocumentsAsync(docsList);
                
                var firstDoc = docsList[0];
                var hasEmbedding = firstDoc.Embedding != null;
                var embeddingDims = hasEmbedding ? firstDoc.Embedding!.Count : 0;
                
                return Results.Ok(new
                {
                    Success = indexed,
                    Message = indexed ? $"Successfully indexed {docsList.Count} document(s)" : "Failed to index documents",
                    DocumentCount = docsList.Count,
                    HasEmbedding = hasEmbedding,
                    EmbeddingDimensions = embeddingDims
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to test Azure Search indexing");
                return Results.Problem($"Error: {ex.Message}\n\nInner: {ex.InnerException?.Message}\n\nStack: {ex.StackTrace}");
            }
        })
        .WithName("TestAzureSearch")
        .WithDescription("Test Azure AI Search connection, index creation, and document indexing")
        .WithOpenApi();

        group.MapDelete("/delete-index", async (IAzureSearchService searchService, ILogger<Program> logger) =>
        {
            try
            {
                logger.LogInformation("Deleting Azure AI Search index...");
                var deleted = await searchService.DeleteIndexAsync();
                
                return Results.Ok(new
                {
                    Success = deleted,
                    Message = deleted ? "Index deleted successfully" : "Failed to delete index"
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to delete index");
                return Results.Problem($"Error: {ex.Message}");
            }
        })
        .WithName("DeleteIndex")
        .WithDescription("Delete the Azure AI Search index")
        .WithOpenApi();
    }
}

public record RagQueryRequest(string Question);
