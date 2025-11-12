using Microsoft.EntityFrameworkCore;
using ProductSales.Data;
using ProductSales.Models;

namespace ProductSales.Services;

public interface IDataMigrationService
{
    Task<(int TotalRecords, int MigratedRecords, TimeSpan Duration)> MigrateFromSqlServerToPostgresAsync();
}

public class DataMigrationService : IDataMigrationService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<DataMigrationService> _logger;

    public DataMigrationService(IServiceProvider serviceProvider, ILogger<DataMigrationService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    public async Task<(int TotalRecords, int MigratedRecords, TimeSpan Duration)> MigrateFromSqlServerToPostgresAsync()
    {
        var startTime = DateTime.UtcNow;
        var migratedCount = 0;

        try
        {
            // Create separate scopes for each context to avoid conflicts
            using var sqlScope = _serviceProvider.CreateScope();
            using var pgScope = _serviceProvider.CreateScope();

            // Get SQL Server context (source)
            var sqlContext = sqlScope.ServiceProvider.GetRequiredService<ContosoRetailContext>();
            
            // Temporarily force it to use SQL Server
            var sqlConnectionString = "Server=localhost,1433;Database=ContosoRetailDW;User Id=sa;Password=Contraseña12345678;TrustServerCertificate=True;Encrypt=Mandatory;";
            var sqlOptionsBuilder = new DbContextOptionsBuilder<ContosoRetailContext>();
            sqlOptionsBuilder.UseSqlServer(sqlConnectionString);
            var sqlServerContext = new ContosoRetailContext(sqlOptionsBuilder.Options);

            // Get PostgreSQL context (destination)
            var pgConnectionString = "Server=pg-contoso-6821.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=2783Postgres;SSL Mode=Require;Trust Server Certificate=true;";
            var pgOptionsBuilder = new DbContextOptionsBuilder<ContosoRetailPostgresContext>();
            pgOptionsBuilder.UseNpgsql(pgConnectionString);
            var pgContext = new ContosoRetailPostgresContext(pgOptionsBuilder.Options);

            _logger.LogInformation("Starting data migration from SQL Server to PostgreSQL...");

            // Get all records from SQL Server
            var sourceData = await sqlServerContext.FactSales.ToListAsync();
            var totalRecords = sourceData.Count;
            _logger.LogInformation($"Found {totalRecords} records in SQL Server");

            // Clear existing data in PostgreSQL (optional - comment out to keep existing data)
            // await pgContext.Database.ExecuteSqlRawAsync("TRUNCATE TABLE public.\"FactSales\" RESTART IDENTITY CASCADE");

            // Batch insert into PostgreSQL
            const int batchSize = 1000;
            for (int i = 0; i < sourceData.Count; i += batchSize)
            {
                var batch = sourceData.Skip(i).Take(batchSize).ToList();
                
                // Reset SalesKey to let PostgreSQL auto-generate
                foreach (var record in batch)
                {
                    record.SalesKey = 0; // Let PostgreSQL generate new IDs
                }

                await pgContext.FactSales.AddRangeAsync(batch);
                await pgContext.SaveChangesAsync();
                
                migratedCount += batch.Count;
                _logger.LogInformation($"Migrated {migratedCount}/{totalRecords} records ({(double)migratedCount / totalRecords * 100:F1}%)");
            }

            var duration = DateTime.UtcNow - startTime;
            _logger.LogInformation($"Migration completed! Migrated {migratedCount} records in {duration.TotalSeconds:F2} seconds");

            return (totalRecords, migratedCount, duration);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during data migration");
            throw;
        }
    }
}
