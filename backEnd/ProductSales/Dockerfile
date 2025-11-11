# Multi-stage Dockerfile for .NET 8 Web API
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ProductSales.csproj .
RUN dotnet restore "ProductSales.csproj"

# Copy everything else and build
COPY . .
RUN dotnet build "ProductSales.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "ProductSales.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Copy published app
COPY --from=publish /app/publish .

# Copy static files (CSV data)
COPY wwwroot ./wwwroot

# Expose port
EXPOSE 8080

# Set environment variables for production
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Run the application
ENTRYPOINT ["dotnet", "ProductSales.dll"]
