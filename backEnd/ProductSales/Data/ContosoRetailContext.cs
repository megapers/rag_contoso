using Microsoft.EntityFrameworkCore;
using ProductSales.Models;

namespace ProductSales.Data;

public class ContosoRetailContext : DbContext
{
    public ContosoRetailContext(DbContextOptions<ContosoRetailContext> options)
        : base(options)
    {
    }

    public DbSet<FactSales> FactSales { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        modelBuilder.Entity<FactSales>(entity =>
        {
            entity.ToTable("FactSales", "dbo");
            entity.HasKey(e => e.SalesKey);
        });
    }
}
