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

        group.MapPost("/index", async (IRagService ragService) =>
        {
            var success = await ragService.IndexDataAsync();
            
            if (success)
            {
                return Results.Ok(new 
                { 
                    success = true, 
                    message = "Data indexed successfully in Azure AI Search" 
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
    }
}

public record RagQueryRequest(string Question);
