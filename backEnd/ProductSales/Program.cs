using Microsoft.EntityFrameworkCore;
using ProductSales.Data;
using ProductSales.Endpoints;
using ProductSales.Repositories;
using ProductSales.Services;

var builder = WebApplication.CreateBuilder(args);

// Add database context
builder.Services.AddDbContext<ContosoRetailContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Add repositories
builder.Services.AddScoped<IFactSalesRepository, FactSalesRepository>();
builder.Services.AddSingleton<IDimProductRepository, DimProductRepository>();

// Add services
builder.Services.AddScoped<IEtlService, EtlService>();
builder.Services.AddScoped<IAzureSearchService, AzureSearchService>();
builder.Services.AddHttpClient<ILlmApiClient, LlmApiClient>();
builder.Services.AddScoped<IRagService, RagService>();

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
                  .AllowAnyHeader()
                  .AllowAnyMethod()
                  .AllowCredentials();
        });
});

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Enable CORS
app.UseCors("AllowReactApp");

// Map API Endpoints
app.MapSalesEndpoints();
app.MapProductEndpoints();
app.MapEtlEndpoints();
app.MapRagEndpoints();

app.Run();
