using Microsoft.EntityFrameworkCore;
using ProductSales.Data;
using ProductSales.Models;

namespace ProductSales.Repositories;

public class FactSalesRepository : IFactSalesRepository
{
    private readonly ContosoRetailContext _context;

    public FactSalesRepository(ContosoRetailContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<FactSales>> GetAllAsync()
    {
        return await _context.FactSales
            .Take(3000) // Limit for demo purposes - enough for meaningful analysis
            .ToListAsync();
    }

    public async Task<FactSales?> GetByIdAsync(int salesKey)
    {
        return await _context.FactSales.FindAsync(salesKey);
    }

    public async Task<IEnumerable<FactSales>> GetByDateRangeAsync(DateTime startDate, DateTime endDate)
    {
        return await _context.FactSales
            .Where(fs => fs.DateKey >= startDate && fs.DateKey <= endDate)
            .ToListAsync();
    }

    public async Task<FactSales> AddAsync(FactSales sale)
    {
        _context.FactSales.Add(sale);
        await _context.SaveChangesAsync();
        return sale;
    }
}
