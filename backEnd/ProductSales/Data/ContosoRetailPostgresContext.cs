using Microsoft.EntityFrameworkCore;
using ProductSales.Models;

namespace ProductSales.Data;

/// <summary>
/// PostgreSQL-specific DbContext for Azure deployment.
/// Uses PostgreSQL-specific configurations and data types.
/// Inherits from ContosoRetailContext for compatibility.
/// </summary>
public class ContosoRetailPostgresContext : ContosoRetailContext
{
    public ContosoRetailPostgresContext(DbContextOptions<ContosoRetailPostgresContext> options)
        : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        modelBuilder.Entity<FactSales>(entity =>
        {
            entity.ToTable("FactSales", "public");
            entity.HasKey(e => e.SalesKey);
            
            // PostgreSQL-specific configurations
            entity.Property(e => e.UnitCost)
                .HasColumnType("numeric(19,4)");
            
            entity.Property(e => e.UnitPrice)
                .HasColumnType("numeric(19,4)");
            
            entity.Property(e => e.ReturnAmount)
                .HasColumnType("numeric(19,4)");
            
            entity.Property(e => e.DiscountAmount)
                .HasColumnType("numeric(19,4)");
            
            entity.Property(e => e.TotalCost)
                .HasColumnType("numeric(19,4)");
            
            entity.Property(e => e.SalesAmount)
                .HasColumnType("numeric(19,4)");
        });
    }
}
