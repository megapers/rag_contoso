# 🔐 Security Guidelines

## Overview

This document outlines security best practices for the RAG Sales Analytics application, including secrets management, deployment security, and general security considerations.

## 🔑 Secrets Management

### Local Development

**Never commit sensitive information to Git.** This project uses configuration files that are excluded via `.gitignore`:

#### Backend Secrets (`appsettings.json`)
- ✅ **Excluded from Git** via `.gitignore`
- ✅ **Template provided**: `appsettings.example.json`
- Contains:
  - SQL Server connection strings with passwords
  - Azure AI Search admin keys
  - LLM API keys

**Setup:**
```powershell
cd backEnd\ProductSales
cp appsettings.example.json appsettings.json
# Edit appsettings.json with your actual credentials
```

#### Frontend Configuration (`.env`)
- ✅ **Excluded from Git** via `.gitignore`
- ✅ **Template provided**: `.env.example`
- Contains:
  - Backend API URL

**Setup:**
```powershell
cd frontEnd
cp .env.example .env
# Verify REACT_APP_API_URL is correct
```

### Production Deployment

#### Azure Key Vault (Recommended)

For production deployments, use **Azure Key Vault** to store secrets:

1. **Create Key Vault:**
   ```bash
   az keyvault create \
     --name "kv-rag-sales-prod" \
     --resource-group "rg-rag-sales" \
     --location "eastus"
   ```

2. **Store secrets:**
   ```bash
   az keyvault secret set --vault-name "kv-rag-sales-prod" \
     --name "SqlConnectionString" \
     --value "Server=...;Password=..."
   
   az keyvault secret set --vault-name "kv-rag-sales-prod" \
     --name "AzureSearchAdminKey" \
     --value "your-admin-key"
   
   az keyvault secret set --vault-name "kv-rag-sales-prod" \
     --name "LlmApiKey" \
     --value "your-llm-api-key"
   ```

3. **Enable Managed Identity** on your Container App:
   ```bash
   az containerapp identity assign \
     --name "ca-rag-backend" \
     --resource-group "rg-rag-sales" \
     --system-assigned
   ```

4. **Grant Key Vault access:**
   ```bash
   az keyvault set-policy \
     --name "kv-rag-sales-prod" \
     --object-id "<managed-identity-principal-id>" \
     --secret-permissions get list
   ```

5. **Reference in Container Apps:**
   ```bash
   az containerapp secret set \
     --name "ca-rag-backend" \
     --resource-group "rg-rag-sales" \
     --secrets \
       sql-conn-str=keyvaultref:https://kv-rag-sales-prod.vault.azure.net/secrets/SqlConnectionString,identityref:/subscriptions/.../managedIdentities/...
   ```

#### Environment Variables

Alternatively, use environment variables in Container Apps (less secure):

```bash
az containerapp update \
  --name "ca-rag-backend" \
  --resource-group "rg-rag-sales" \
  --set-env-vars \
    "ConnectionStrings__DefaultConnection=secretref:sql-conn-str" \
    "AzureSearch__AdminKey=secretref:search-key" \
    "LlmApi__ApiKey=secretref:llm-key"
```

## 🛡️ Security Best Practices

### API Keys and Credentials

- ✅ **Never hardcode** API keys in source code
- ✅ **Use separate keys** for dev, staging, and production
- ✅ **Rotate keys regularly** (quarterly recommended)
- ✅ **Use least privilege** - give minimum required permissions
- ✅ **Monitor usage** - set up alerts for unusual API consumption
- ⚠️ **Revoke immediately** if keys are exposed

### SQL Server Security

```json
// Development (local)
"Server=localhost,1433;Database=ContosoRetailDW;User Id=appuser;Password=***;TrustServerCertificate=True;Encrypt=Mandatory;"

// Production (Azure SQL)
"Server=tcp:sql-rag-prod.database.windows.net,1433;Database=ContosoRetailDW;Authentication=Active Directory Managed Identity;Encrypt=Mandatory;"
```

**Recommendations:**
- ✅ Use **SQL authentication** for development
- ✅ Use **Managed Identity** for Azure SQL in production
- ✅ Enable **firewall rules** to allow only specific IPs/services
- ✅ Use **TLS/SSL encryption** (Encrypt=Mandatory)
- ✅ Create **dedicated app user** with minimal permissions (no sa/admin)
- ✅ Enable **Advanced Threat Protection** in Azure SQL

### Azure AI Search Security

**Recommendations:**
- ✅ Use **Query keys** for read-only operations (not admin keys)
- ✅ Enable **managed identity** for service-to-service auth
- ✅ Configure **IP firewall** to restrict access
- ✅ Use **private endpoints** for production workloads
- ✅ Enable **diagnostic logging** to monitor access

### LLM API Security

**Considerations:**
- ✅ **Rate limiting** - implement client-side throttling
- ✅ **Input validation** - sanitize user queries before sending to LLM
- ✅ **Output filtering** - validate LLM responses
- ⚠️ **Cost monitoring** - set budget alerts
- ⚠️ **PII/PHI handling** - don't send sensitive data to external LLMs
- ✅ **API key scoping** - use keys with limited permissions

### CORS Configuration

Current backend CORS policy (development):
```csharp
policy.WithOrigins("http://localhost:3000", "http://localhost:3001")
      .AllowAnyHeader()
      .AllowAnyMethod()
      .AllowCredentials();
```

**Production CORS:**
```csharp
// Update Program.cs for production
policy.WithOrigins("https://your-frontend.azurestaticapps.net")
      .WithHeaders("Content-Type", "Authorization")
      .WithMethods("GET", "POST")
      .AllowCredentials();
```

**Recommendations:**
- ✅ **Restrict origins** - only allow your frontend domain
- ✅ **Limit methods** - only allow required HTTP methods
- ✅ **Limit headers** - don't use `AllowAnyHeader()` in production
- ✅ **Use HTTPS** - enforce secure connections

### HTTPS/TLS

**Development:**
```powershell
# Trust development certificate
dotnet dev-certs https --trust
```

**Production:**
- ✅ **Always use HTTPS** - no HTTP endpoints
- ✅ **Use TLS 1.2+** - disable older protocols
- ✅ **Valid certificates** - use Azure-managed certificates
- ✅ **HSTS headers** - enforce HTTPS on client side

### Input Validation

**Backend validation:**
```csharp
// In RagEndpoints.cs or middleware
if (string.IsNullOrWhiteSpace(request.Question) || request.Question.Length > 500)
{
    return Results.BadRequest("Invalid question length");
}

// Sanitize input
var sanitized = Regex.Replace(request.Question, @"[^\w\s?.,'-]", "");
```

**Frontend validation:**
```javascript
// In QueryInput.js
const sanitizeInput = (input) => {
  return input.trim().slice(0, 500); // Max 500 chars
};
```

### Dependency Security

**Backend:**
```powershell
# Check for vulnerable packages
dotnet list package --vulnerable --include-transitive

# Update packages regularly
dotnet outdated
```

**Frontend:**
```bash
# Audit npm packages
npm audit

# Fix vulnerabilities
npm audit fix

# Update dependencies
npm update
```

### Logging and Monitoring

**What to log:**
- ✅ Authentication/authorization events
- ✅ API usage patterns
- ✅ Error conditions
- ✅ Performance metrics

**What NOT to log:**
- ⛔ Passwords or API keys
- ⛔ Connection strings
- ⛔ PII (Personally Identifiable Information)
- ⛔ Full request/response bodies with sensitive data

**Implementation:**
```csharp
// In RagService.cs
_logger.LogInformation("RAG query processed for question: {QuestionLength} chars", question.Length);
// Don't log: _logger.LogInformation("Query: {Question}", question); // May contain PII
```

## 🚨 Incident Response

### If API Keys Are Exposed

1. **Immediately revoke** the exposed key
2. **Generate new key** and update configuration
3. **Review access logs** for unauthorized usage
4. **Notify stakeholders** if data breach occurred
5. **Update secrets management** process to prevent recurrence

### If Database Credentials Are Compromised

1. **Immediately change** database password
2. **Review database audit logs** for unauthorized access
3. **Check for data exfiltration**
4. **Reset all application credentials**
5. **Enable additional security** (MFA, stricter firewall rules)

## 📋 Security Checklist

### Before First Commit
- [ ] Verify `.gitignore` excludes `appsettings.json` and `.env`
- [ ] Replace real credentials with placeholders in example files
- [ ] Remove any hardcoded secrets from source code
- [ ] Test that `git status` doesn't show sensitive files

### Before Deployment
- [ ] Set up Azure Key Vault for production secrets
- [ ] Enable Managed Identity for Azure services
- [ ] Configure production CORS with specific origins
- [ ] Enable HTTPS/TLS for all endpoints
- [ ] Set up firewall rules for SQL and AI Search
- [ ] Review and restrict service principal permissions
- [ ] Enable diagnostic logging
- [ ] Set up cost alerts for LLM API usage

### Regular Maintenance
- [ ] Rotate API keys quarterly
- [ ] Update dependencies monthly (`npm audit`, `dotnet list package --vulnerable`)
- [ ] Review access logs weekly
- [ ] Test disaster recovery procedures
- [ ] Audit Key Vault access policies

## 📚 Additional Resources

- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Azure SQL Security Best Practices](https://learn.microsoft.com/en-us/azure/azure-sql/database/security-best-practice)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Azure Security Baseline](https://learn.microsoft.com/en-us/security/benchmark/azure/)

---

**Remember: Security is an ongoing process, not a one-time setup. Stay vigilant! 🔐**
