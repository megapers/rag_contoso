using ProductSales.Models.DTOs;

namespace ProductSales.Services;

public interface IEtlService
{
    /// <summary>
    /// Executes the ETL pipeline: Extract from SQL + CSV, Transform by joining, Load to output
    /// </summary>
    Task<EtlResult> ExecutePipelineAsync();

    /// <summary>
    /// Gets the enriched data without triggering a full pipeline execution
    /// </summary>
    Task<IEnumerable<ProductSalesEnriched>> GetEnrichedDataAsync(int? limit = null);
}

public class EtlResult
{
    public bool Success { get; set; }
    public int RecordsProcessed { get; set; }
    public DateTime ExecutedAt { get; set; }
    public TimeSpan Duration { get; set; }
    public string Message { get; set; } = string.Empty;
    public List<string> Errors { get; set; } = new();
}
