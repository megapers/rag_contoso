using Azure.Search.Documents.Indexes;
using Azure.Search.Documents.Indexes.Models;

namespace ProductSales.Models.DTOs;

/// <summary>
/// Enriched model combining FactSales and DimProduct for RAG indexing
/// </summary>
public class ProductSalesEnriched
{
    // Sales Information
    [SimpleField(IsKey = true, IsFilterable = true)]
    public string SalesKey { get; set; } = string.Empty;
    
    [SimpleField(IsFilterable = true, IsSortable = true)]
    public DateTime DateKey { get; set; }
    
    [SimpleField(IsFilterable = true, IsSortable = true)]
    public int SalesQuantity { get; set; }
    
    [SimpleField(IsFilterable = true, IsSortable = true)]
    public double UnitCost { get; set; }
    
    [SimpleField(IsFilterable = true, IsSortable = true)]
    public double UnitPrice { get; set; }
    
    [SimpleField(IsFilterable = true, IsSortable = true)]
    public double SalesAmount { get; set; }
    
    [SimpleField(IsFilterable = true, IsSortable = true)]
    public double TotalCost { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public int ReturnQuantity { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public double? ReturnAmount { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public int? DiscountQuantity { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public double? DiscountAmount { get; set; }

    // Product Information
    [SimpleField(IsFilterable = true)]
    public int ProductKey { get; set; }
    
    [SearchableField(IsFilterable = true, IsSortable = true)]
    public string ProductName { get; set; } = string.Empty;
    
    [SearchableField]
    public string ProductDescription { get; set; } = string.Empty;
    
    [SearchableField(IsFilterable = true, IsFacetable = true)]
    public string Manufacturer { get; set; } = string.Empty;
    
    [SearchableField(IsFilterable = true, IsFacetable = true)]
    public string BrandName { get; set; } = string.Empty;
    
    [SearchableField(IsFilterable = true, IsFacetable = true)]
    public string ClassName { get; set; } = string.Empty;
    
    [SearchableField(IsFilterable = true)]
    public string StyleName { get; set; } = string.Empty;
    
    [SearchableField(IsFilterable = true, IsFacetable = true)]
    public string ColorName { get; set; } = string.Empty;
    
    [SearchableField(IsFilterable = true)]
    public string Status { get; set; } = string.Empty;

    // Foreign Keys for potential further joins
    [SimpleField(IsFilterable = true)]
    public int ChannelKey { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public int StoreKey { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public int PromotionKey { get; set; }
    
    [SimpleField(IsFilterable = true)]
    public int CurrencyKey { get; set; }

    // Vector Search Field for semantic similarity
    [VectorSearchField(VectorSearchDimensions = 384, VectorSearchProfileName = "vector-profile")]
    public IReadOnlyList<float>? Embedding { get; set; }

    // Calculated Fields (not indexed)
    public double ProfitMargin => UnitPrice > 0 ? ((UnitPrice - UnitCost) / UnitPrice) * 100 : 0;
    public double NetSalesAmount => SalesAmount - (ReturnAmount ?? 0) - (DiscountAmount ?? 0);

    // For RAG - Searchable text representation
    [SearchableField(AnalyzerName = LexicalAnalyzerName.Values.EnLucene)]
    public string SearchableText => 
        $"Sale of {ProductName} by {Manufacturer} ({BrandName}). " +
        $"Product: {ProductDescription}. " +
        $"Category: {ClassName}, Style: {StyleName}, Color: {ColorName}. " +
        $"Date: {DateKey:yyyy-MM-dd}. " +
        $"Quantity: {SalesQuantity} units at ${UnitPrice} each. " +
        $"Total sales: ${SalesAmount}. " +
        $"Status: {Status}.";
}
