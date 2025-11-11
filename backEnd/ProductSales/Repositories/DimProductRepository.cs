using CsvHelper;
using CsvHelper.Configuration;
using ProductSales.Models;
using System.Globalization;

namespace ProductSales.Repositories;

public class DimProductRepository : IDimProductRepository
{
    private readonly string _csvFilePath;
    private readonly IWebHostEnvironment _environment;
    private List<DimProduct>? _products;

    public DimProductRepository(IWebHostEnvironment environment)
    {
        _environment = environment;
        _csvFilePath = Path.Combine(_environment.WebRootPath, "DimProduct.csv");
    }

    private async Task<List<DimProduct>> LoadProductsAsync()
    {
        if (_products != null)
            return _products;

        var config = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HasHeaderRecord = true,
            MissingFieldFound = null
        };

        using var reader = new StreamReader(_csvFilePath);
        using var csv = new CsvReader(reader, config);
        
        _products = csv.GetRecords<DimProduct>().ToList();
        
        return _products;
    }

    public async Task<IEnumerable<DimProduct>> GetAllAsync()
    {
        var products = await LoadProductsAsync();
        return products;
    }

    public async Task<DimProduct?> GetByIdAsync(int productKey)
    {
        var products = await LoadProductsAsync();
        return products.FirstOrDefault(p => p.ProductKey == productKey);
    }

    public async Task<IEnumerable<DimProduct>> GetByNameAsync(string productName)
    {
        var products = await LoadProductsAsync();
        return products.Where(p => p.ProductName.Contains(productName, StringComparison.OrdinalIgnoreCase));
    }

    public async Task<IEnumerable<DimProduct>> GetBySubcategoryAsync(int subcategoryKey)
    {
        var products = await LoadProductsAsync();
        return products.Where(p => p.ProductSubcategoryKey == subcategoryKey);
    }

    public async Task<IEnumerable<DimProduct>> GetByManufacturerAsync(string manufacturer)
    {
        var products = await LoadProductsAsync();
        return products.Where(p => p.Manufacturer.Contains(manufacturer, StringComparison.OrdinalIgnoreCase));
    }
}
