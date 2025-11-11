using ProductSales.Services;

namespace ProductSales.Endpoints;

public static class EtlEndpoints
{
    public static void MapEtlEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/etl")
            .WithTags("ETL Pipeline");

        group.MapPost("/sync", async (IEtlService etlService) =>
        {
            var result = await etlService.ExecutePipelineAsync();
            
            if (result.Success)
            {
                return Results.Ok(result);
            }
            
            return Results.BadRequest(result);
        })
        .WithName("TriggerETLPipeline")
        .WithDescription("Triggers the ETL pipeline to extract, transform, and load sales data")
        .WithOpenApi();

        group.MapGet("/enriched-data", async (IEtlService etlService, int? limit) =>
        {
            var data = await etlService.GetEnrichedDataAsync(limit);
            return Results.Ok(data);
        })
        .WithName("GetEnrichedData")
        .WithDescription("Gets the enriched sales data without triggering a full ETL pipeline")
        .WithOpenApi();

        group.MapGet("/status", () =>
        {
            return Results.Ok(new
            {
                Status = "Ready",
                Message = "ETL service is ready to process data",
                Timestamp = DateTime.UtcNow
            });
        })
        .WithName("GetETLStatus")
        .WithDescription("Check the status of the ETL service")
        .WithOpenApi();
    }
}
