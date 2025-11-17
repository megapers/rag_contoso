using Microsoft.EntityFrameworkCore;
using ProductSales.Data;
using ProductSales.Endpoints;
using ProductSales.Repositories;
using ProductSales.Services;

var builder = WebApplication.CreateBuilder(args);

// Determine which database provider to use based on environment
var usePostgres = builder.Configuration.GetValue<bool>("UsePostgreSQL") || 
                  builder.Environment.IsProduction() ||
                  !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("USE_POSTGRESQL"));

// Add database context - SQL Server for local, PostgreSQL for Azure/Production
if (usePostgres)
{
    builder.Services.AddDbContext<ContosoRetailContext, ContosoRetailPostgresContext>(options =>
        options.UseNpgsql(builder.Configuration.GetConnectionString("PostgresConnection")));
}
else
{
    builder.Services.AddDbContext<ContosoRetailContext>(options =>
        options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
}

// Add repositories
builder.Services.AddScoped<IFactSalesRepository, FactSalesRepository>();
builder.Services.AddSingleton<IDimProductRepository, DimProductRepository>();

// Add services
builder.Services.AddScoped<IEtlService, EtlService>();
builder.Services.AddScoped<IAzureSearchService, AzureSearchService>();
builder.Services.AddSingleton<IEmbeddingService, EmbeddingService>();
builder.Services.AddHttpClient<ILlmApiClient, LlmApiClient>();
builder.Services.AddScoped<IRagService, RagService>();
builder.Services.AddScoped<IDataMigrationService, DataMigrationService>();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowReactApp",
        policy =>
        {
            policy.WithOrigins(
                    "http://localhost:3000", 
                    "http://localhost:3001",
                    "https://localhost:3000",
                    "https://localhost:3001")
                  .SetIsOriginAllowedToAllowWildcardSubdomains()
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        });
    
    // Add policy for Vercel deployment
    options.AddPolicy("AllowVercel",
        policy =>
        {
            policy.SetIsOriginAllowed(origin =>
                {
                    if (string.IsNullOrWhiteSpace(origin)) return false;
                    var uri = new Uri(origin);
                    return uri.Host.EndsWith(".vercel.app") || 
                           uri.Host == "localhost" ||
                           uri.Host.EndsWith("azurecontainerapps.io");
                })
                .AllowAnyHeader()
                .AllowAnyMethod();
        });
});

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseSwagger();
app.UseSwaggerUI();

// Enable CORS
app.UseCors("AllowVercel");

// Map API Endpoints
app.MapSalesEndpoints();
app.MapProductEndpoints();
app.MapEtlEndpoints();
app.MapRagEndpoints();
app.MapMigrationEndpoints();

app.Run();
