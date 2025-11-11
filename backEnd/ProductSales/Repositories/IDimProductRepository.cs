using ProductSales.Models;

namespace ProductSales.Repositories;

public interface IDimProductRepository
{
    Task<IEnumerable<DimProduct>> GetAllAsync();
    Task<DimProduct?> GetByIdAsync(int productKey);
    Task<IEnumerable<DimProduct>> GetByNameAsync(string productName);
    Task<IEnumerable<DimProduct>> GetBySubcategoryAsync(int subcategoryKey);
    Task<IEnumerable<DimProduct>> GetByManufacturerAsync(string manufacturer);
}
