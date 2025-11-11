using ProductSales.Models;

namespace ProductSales.Repositories;

public interface IFactSalesRepository
{
    Task<IEnumerable<FactSales>> GetAllAsync();
    Task<FactSales?> GetByIdAsync(int salesKey);
    Task<IEnumerable<FactSales>> GetByDateRangeAsync(DateTime startDate, DateTime endDate);
}
