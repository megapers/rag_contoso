using ProductSales.Models;
using ProductSales.Repositories;

namespace ProductSales.Endpoints;

public static class SalesEndpoints
{
    public static void MapSalesEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/sales", async (IFactSalesRepository repository) =>
        {
            var sales = await repository.GetAllAsync();
            return Results.Ok(sales);
        })
        .WithName("GetAllSales")
        .WithOpenApi();

        app.MapGet("/api/sales/{id}", async (int id, IFactSalesRepository repository) =>
        {
            var sale = await repository.GetByIdAsync(id);
            return sale is not null ? Results.Ok(sale) : Results.NotFound();
        })
        .WithName("GetSaleById")
        .WithOpenApi();

        app.MapPost("/api/sales", async (FactSales sale, IFactSalesRepository repository) =>
        {
            if (sale == null)
                return Results.BadRequest("Sale data is required");

            // Set system fields
            sale.LoadDate = DateTime.UtcNow;
            sale.UpdateDate = DateTime.UtcNow;

            var createdSale = await repository.AddAsync(sale);
            return Results.Created($"/api/sales/{createdSale.SalesKey}", createdSale);
        })
        .WithName("CreateSale")
        .WithOpenApi();
    }
}
