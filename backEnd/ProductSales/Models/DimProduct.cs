using CsvHelper.Configuration.Attributes;

namespace ProductSales.Models;

public class DimProduct
{
    [Index(0)]
    public int ProductKey { get; set; }

    [Index(1)]
    public string ProductName { get; set; } = string.Empty;

    [Index(2)]
    public string ProductDescription { get; set; } = string.Empty;

    [Index(3)]
    public int ProductSubcategoryKey { get; set; }

    [Index(4)]
    public string Manufacturer { get; set; } = string.Empty;

    [Index(5)]
    public string BrandName { get; set; } = string.Empty;

    [Index(6)]
    public int ClassID { get; set; }

    [Index(7)]
    public string ClassName { get; set; } = string.Empty;

    [Index(8)]
    public int StyleID { get; set; }

    [Index(9)]
    public string StyleName { get; set; } = string.Empty;

    [Index(10)]
    public int ColorID { get; set; }

    [Index(11)]
    public string ColorName { get; set; } = string.Empty;

    [Index(12)]
    public decimal? Weight { get; set; }

    [Index(13)]
    public string? WeightUnitMeasureID { get; set; }

    [Index(14)]
    public int UnitOfMeasureID { get; set; }

    [Index(15)]
    public string UnitOfMeasureName { get; set; } = string.Empty;

    [Index(16)]
    public int StockTypeID { get; set; }

    [Index(17)]
    public string StockTypeName { get; set; } = string.Empty;

    [Index(18)]
    public decimal UnitCost { get; set; }

    [Index(19)]
    public decimal UnitPrice { get; set; }

    [Index(20)]
    public DateTime AvailableForSaleDate { get; set; }

    [Index(21)]
    public string Status { get; set; } = string.Empty;
}
