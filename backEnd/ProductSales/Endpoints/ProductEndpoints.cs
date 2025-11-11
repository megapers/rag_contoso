using ProductSales.Repositories;

namespace ProductSales.Endpoints;

public static class ProductEndpoints
{
    public static void MapProductEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/products", async (IDimProductRepository repository) =>
        {
            var products = await repository.GetAllAsync();
            return Results.Ok(products);
        })
        .WithName("GetAllProducts")
        .WithOpenApi();

        app.MapGet("/api/products/{id}", async (int id, IDimProductRepository repository) =>
        {
            var product = await repository.GetByIdAsync(id);
            return product is not null ? Results.Ok(product) : Results.NotFound();
        })
        .WithName("GetProductById")
        .WithOpenApi();

        app.MapGet("/api/products/search/name/{name}", async (string name, IDimProductRepository repository) =>
        {
            var products = await repository.GetByNameAsync(name);
            return Results.Ok(products);
        })
        .WithName("GetProductsByName")
        .WithOpenApi();

        app.MapGet("/api/products/subcategory/{subcategoryKey}", async (int subcategoryKey, IDimProductRepository repository) =>
        {
            var products = await repository.GetBySubcategoryAsync(subcategoryKey);
            return Results.Ok(products);
        })
        .WithName("GetProductsBySubcategory")
        .WithOpenApi();

        app.MapGet("/api/products/manufacturer/{manufacturer}", async (string manufacturer, IDimProductRepository repository) =>
        {
            var products = await repository.GetByManufacturerAsync(manufacturer);
            return Results.Ok(products);
        })
        .WithName("GetProductsByManufacturer")
        .WithOpenApi();
    }
}
