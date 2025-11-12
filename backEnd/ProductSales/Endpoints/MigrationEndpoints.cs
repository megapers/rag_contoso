using ProductSales.Services;

namespace ProductSales.Endpoints;

public static class MigrationEndpoints
{
    public static void MapMigrationEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/admin/migrate-data", async (IDataMigrationService migrationService) =>
        {
            try
            {
                var result = await migrationService.MigrateFromSqlServerToPostgresAsync();
                
                return Results.Ok(new
                {
                    success = true,
                    message = "Data migration completed successfully",
                    totalRecords = result.TotalRecords,
                    migratedRecords = result.MigratedRecords,
                    durationSeconds = result.Duration.TotalSeconds,
                    durationFormatted = $"{result.Duration.Minutes}m {result.Duration.Seconds}s"
                });
            }
            catch (Exception ex)
            {
                return Results.Problem(
                    title: "Migration Failed",
                    detail: ex.Message,
                    statusCode: 500
                );
            }
        })
        .WithName("MigrateData")
        .WithOpenApi()
        .WithDescription("Migrates data from local SQL Server to Azure PostgreSQL");
    }
}
