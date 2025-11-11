using ProductSales.Models.DTOs;
using ProductSales.Repositories;
using System.Diagnostics;
using System.Text.Json;

namespace ProductSales.Services;

public class EtlService : IEtlService
{
    private readonly IFactSalesRepository _salesRepository;
    private readonly IDimProductRepository _productRepository;
    private readonly ILogger<EtlService> _logger;
    private readonly IWebHostEnvironment _environment;

    public EtlService(
        IFactSalesRepository salesRepository,
        IDimProductRepository productRepository,
        ILogger<EtlService> logger,
        IWebHostEnvironment environment)
    {
        _salesRepository = salesRepository;
        _productRepository = productRepository;
        _logger = logger;
        _environment = environment;
    }

    public async Task<EtlResult> ExecutePipelineAsync()
    {
        var stopwatch = Stopwatch.StartNew();
        var result = new EtlResult
        {
            ExecutedAt = DateTime.UtcNow
        };

        try
        {
            _logger.LogInformation("Starting ETL pipeline execution...");

            // Extract
            _logger.LogInformation("Extracting data from sources...");
            var sales = await _salesRepository.GetAllAsync();
            var products = await _productRepository.GetAllAsync();

            // Transform - Join sales with products
            _logger.LogInformation("Transforming data - joining sales with products...");
            var productDict = products.ToDictionary(p => p.ProductKey, p => p);
            
            var enrichedData = sales
                .Where(s => productDict.ContainsKey(s.ProductKey))
                .Select(s => new ProductSalesEnriched
                {
                    // Sales fields
                    SalesKey = s.SalesKey.ToString(),
                    DateKey = s.DateKey,
                    SalesQuantity = s.SalesQuantity,
                    UnitCost = (double)s.UnitCost,
                    UnitPrice = (double)s.UnitPrice,
                    SalesAmount = (double)s.SalesAmount,
                    TotalCost = (double)s.TotalCost,
                    ReturnQuantity = s.ReturnQuantity,
                    ReturnAmount = (double?)s.ReturnAmount,
                    DiscountQuantity = s.DiscountQuantity,
                    DiscountAmount = (double?)s.DiscountAmount,
                    ChannelKey = s.ChannelKey,
                    StoreKey = s.StoreKey,
                    PromotionKey = s.PromotionKey,
                    CurrencyKey = s.CurrencyKey,
                    
                    // Product fields
                    ProductKey = s.ProductKey,
                    ProductName = productDict[s.ProductKey].ProductName,
                    ProductDescription = productDict[s.ProductKey].ProductDescription,
                    Manufacturer = productDict[s.ProductKey].Manufacturer,
                    BrandName = productDict[s.ProductKey].BrandName,
                    ClassName = productDict[s.ProductKey].ClassName,
                    StyleName = productDict[s.ProductKey].StyleName,
                    ColorName = productDict[s.ProductKey].ColorName,
                    Status = productDict[s.ProductKey].Status
                })
                .ToList();

            // Load - Save sample to output directory (full data goes to Azure AI Search via /api/rag/index)
            _logger.LogInformation("Saving sample data to output...");
            var outputPath = Path.Combine(_environment.ContentRootPath, "ETL_Output");
            Directory.CreateDirectory(outputPath);

            var fileName = $"enriched_sales_sample_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json";
            var filePath = Path.Combine(outputPath, fileName);

            // Only save first 1000 records to file to avoid memory issues
            var sampleData = enrichedData.Take(1000).ToList();
            
            var jsonOptions = new JsonSerializerOptions 
            { 
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            
            var json = JsonSerializer.Serialize(sampleData, jsonOptions);
            await File.WriteAllTextAsync(filePath, json);

            stopwatch.Stop();

            result.Success = true;
            result.RecordsProcessed = enrichedData.Count;
            result.Duration = stopwatch.Elapsed;
            result.Message = $"ETL pipeline completed successfully. {enrichedData.Count} records processed. Sample of {sampleData.Count} records saved to {fileName}. Use /api/rag/index to index all data.";

            _logger.LogInformation(
                "ETL pipeline completed. Records: {RecordsProcessed}, Duration: {Duration}ms",
                result.RecordsProcessed,
                result.Duration.TotalMilliseconds);

            return result;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(ex, "ETL pipeline failed");

            result.Success = false;
            result.Duration = stopwatch.Elapsed;
            result.Message = "ETL pipeline failed";
            result.Errors.Add(ex.Message);

            return result;
        }
    }

    public async Task<IEnumerable<ProductSalesEnriched>> GetEnrichedDataAsync(int? limit = null)
    {
        _logger.LogInformation("Getting enriched data (limit: {Limit})...", limit ?? -1);

        var sales = await _salesRepository.GetAllAsync();
        var products = await _productRepository.GetAllAsync();
        
        var productDict = products.ToDictionary(p => p.ProductKey, p => p);
        
        var query = sales
            .Where(s => productDict.ContainsKey(s.ProductKey))
            .Select(s => new ProductSalesEnriched
            {
                SalesKey = s.SalesKey.ToString(),
                DateKey = s.DateKey,
                SalesQuantity = s.SalesQuantity,
                UnitCost = (double)s.UnitCost,
                UnitPrice = (double)s.UnitPrice,
                SalesAmount = (double)s.SalesAmount,
                TotalCost = (double)s.TotalCost,
                ReturnQuantity = s.ReturnQuantity,
                ReturnAmount = (double?)s.ReturnAmount,
                DiscountQuantity = s.DiscountQuantity,
                DiscountAmount = (double?)s.DiscountAmount,
                ChannelKey = s.ChannelKey,
                StoreKey = s.StoreKey,
                PromotionKey = s.PromotionKey,
                CurrencyKey = s.CurrencyKey,
                ProductKey = s.ProductKey,
                ProductName = productDict[s.ProductKey].ProductName,
                ProductDescription = productDict[s.ProductKey].ProductDescription,
                Manufacturer = productDict[s.ProductKey].Manufacturer,
                BrandName = productDict[s.ProductKey].BrandName,
                ClassName = productDict[s.ProductKey].ClassName,
                StyleName = productDict[s.ProductKey].StyleName,
                ColorName = productDict[s.ProductKey].ColorName,
                Status = productDict[s.ProductKey].Status
            });

        if (limit.HasValue)
        {
            query = query.Take(limit.Value);
        }

        return query.ToList();
    }
}
