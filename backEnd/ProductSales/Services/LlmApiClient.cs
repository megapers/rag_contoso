using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ProductSales.Services;

public interface ILlmApiClient
{
    Task<LlmResponse> ChatCompletionAsync(string systemPrompt, string userPrompt);
}

public class LlmApiClient : ILlmApiClient
{
    private readonly HttpClient _httpClient;
    private readonly string _apiKey;
    private readonly string _model;
    private readonly ILogger<LlmApiClient> _logger;

    public LlmApiClient(HttpClient httpClient, IConfiguration configuration, ILogger<LlmApiClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        
        var baseUrl = configuration["LlmApi:BaseUrl"] ?? "https://api.deepseek.com";
        _apiKey = configuration["LlmApi:ApiKey"] 
            ?? throw new InvalidOperationException("LLM API key not configured");
        _model = configuration["LlmApi:Model"] ?? "deepseek-chat";

        _httpClient.BaseAddress = new Uri(baseUrl);
        _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {_apiKey}");
    }

    public async Task<LlmResponse> ChatCompletionAsync(string systemPrompt, string userPrompt)
    {
        try
        {
            _logger.LogInformation("Calling LLM API with model: {Model}", _model);

            var request = new LlmRequest
            {
                Model = _model,
                Messages = new List<LlmMessage>
                {
                    new LlmMessage { Role = "system", Content = systemPrompt },
                    new LlmMessage { Role = "user", Content = userPrompt }
                }
            };

            var json = JsonSerializer.Serialize(request, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            });

            var content = new StringContent(json, Encoding.UTF8, "application/json");
            var response = await _httpClient.PostAsync("/chat/completions", content);

            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadAsStringAsync();
                _logger.LogError("LLM API error: {StatusCode} - {Error}", response.StatusCode, error);
                throw new HttpRequestException($"LLM API returned {response.StatusCode}: {error}");
            }

            var responseJson = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<LlmResponse>(responseJson, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                PropertyNameCaseInsensitive = true
            });

            _logger.LogInformation("LLM API call successful");
            return result ?? throw new InvalidOperationException("Failed to deserialize LLM response");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to call LLM API");
            throw;
        }
    }
}

// DTOs for LLM API (OpenAI-compatible)
public class LlmRequest
{
    public string Model { get; set; } = string.Empty;
    public List<LlmMessage> Messages { get; set; } = new();
}

public class LlmMessage
{
    public string Role { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
}

public class LlmResponse
{
    public string Id { get; set; } = string.Empty;
    public string Model { get; set; } = string.Empty;
    public List<LlmChoice> Choices { get; set; } = new();
    public LlmUsage? Usage { get; set; }
}

public class LlmChoice
{
    public int Index { get; set; }
    public LlmMessage? Message { get; set; }
    public string? FinishReason { get; set; }
}

public class LlmUsage
{
    public int PromptTokens { get; set; }
    public int CompletionTokens { get; set; }
    public int TotalTokens { get; set; }
}
