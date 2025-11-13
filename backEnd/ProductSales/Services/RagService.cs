using ProductSales.Models.DTOs;
using System.Text.Json;

namespace ProductSales.Services;

public interface IRagService
{
    Task<RagResponse> QueryAsync(string question);
    Task<bool> IndexDataAsync();
}

public class RagService : IRagService
{
    private readonly IAzureSearchService _searchService;
    private readonly ILlmApiClient _llmClient;
    private readonly IEtlService _etlService;
    private readonly ILogger<RagService> _logger;

    public RagService(
        IAzureSearchService searchService,
        ILlmApiClient llmClient,
        IEtlService etlService,
        ILogger<RagService> logger)
    {
        _searchService = searchService;
        _llmClient = llmClient;
        _etlService = etlService;
        _logger = logger;
    }

    public async Task<bool> IndexDataAsync()
    {
        try
        {
            _logger.LogInformation("Starting RAG data indexing...");

            // Create or update index
            var indexCreated = await _searchService.CreateOrUpdateIndexAsync();
            if (!indexCreated)
            {
                return false;
            }

            // Get enriched data
            var enrichedData = await _etlService.GetEnrichedDataAsync();

            // Index documents
            var indexed = await _searchService.IndexDocumentsAsync(enrichedData);

            _logger.LogInformation("RAG data indexing completed successfully");
            return indexed;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to index data for RAG");
            return false;
        }
    }

    public async Task<RagResponse> QueryAsync(string question)
    {
        try
        {
            _logger.LogInformation("Processing RAG query: {Question}", question);

            // Detect if this is a predictive/forecasting query
            var isPredictiveQuery = IsPredictiveQuery(question);
            
            // Step 1: Extract date filter if present (but not for predictive queries about future dates)
            string? dateFilter = null;
            if (!isPredictiveQuery)
            {
                dateFilter = ExtractDateFilter(question);
            }
            else
            {
                // For predictive queries, don't filter by the future date being asked about
                // We need historical data to make the prediction
                _logger.LogInformation("Predictive query detected - retrieving historical data for forecasting");
            }

            // Step 2: Retrieve relevant documents from Azure AI Search with increased results
            // For predictive queries, we need more historical data
            var topResults = isPredictiveQuery ? 50 : 10;
            var searchResults = await _searchService.SearchAsync(question, top: topResults, dateFilter);

            var relevantDocs = new List<ProductSalesEnriched>();
            await foreach (var result in searchResults.GetResultsAsync())
            {
                relevantDocs.Add(result.Document);
            }

            if (!relevantDocs.Any())
            {
                _logger.LogInformation("No relevant documents found for query: {Question}", question);
                return new RagResponse
                {
                    Answer = $"I couldn't find any sales data matching your question about '{question}'. The available data might not cover that time period or those specific products. Please try asking about a different time period or product.",
                    Success = true, // Changed to true - no data is a valid response, not an error
                    ChartData = null
                };
            }

            // Step 2.5: Rerank and deduplicate results for better consistency
            var rankedDocs = ReRankDocuments(relevantDocs, question);

            // Step 3: Build context for LLM
            string context;
            string systemPrompt;
            
            if (isPredictiveQuery)
            {
                // For predictive queries, provide time-series aggregated data
                context = BuildTimeSeriesContext(relevantDocs);
                systemPrompt = GetPredictiveSystemPrompt();
            }
            else
            {
                // For regular queries, use standard context
                context = BuildContext(rankedDocs);
                systemPrompt = GetStandardSystemPrompt();
            }

            // Step 4: Create user prompt
            var userPrompt = BuildUserPrompt(question, context, isPredictiveQuery);

            // Step 4: Call LLM API
            var llmResponse = await _llmClient.ChatCompletionAsync(systemPrompt, userPrompt);

            // Step 5: Parse response
            var responseContent = llmResponse.Choices?.FirstOrDefault()?.Message?.Content ?? "";
            
            _logger.LogDebug("Raw LLM response: {Response}", responseContent);
            
            // Try to parse the JSON response
            RagResponse ragResponse;
            string cleanedResponse = responseContent.Trim(); // Declare outside try block
            try
            {
                // Clean the response (remove markdown code blocks if present)
                
                // Use regex to extract JSON between markdown code blocks
                var jsonBlockPattern = @"```(?:json)?[\s\r\n]*(.*?)[\s\r\n]*```";
                var match = System.Text.RegularExpressions.Regex.Match(
                    cleanedResponse, 
                    jsonBlockPattern, 
                    System.Text.RegularExpressions.RegexOptions.Singleline | System.Text.RegularExpressions.RegexOptions.IgnoreCase
                );
                
                if (match.Success)
                {
                    // Extract the JSON content from within the code block
                    cleanedResponse = match.Groups[1].Value.Trim();
                    _logger.LogDebug("Extracted JSON from markdown block");
                }
                
                _logger.LogDebug("Cleaned response: {Response}", cleanedResponse);

                ragResponse = JsonSerializer.Deserialize<RagResponse>(cleanedResponse, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? new RagResponse { Answer = responseContent, Success = true };
                
                // Validate that chartData was parsed correctly
                // Check if LLM returned nested JSON (entire JSON object as string in answer field)
                if (ragResponse.ChartData == null && ragResponse.Answer != null)
                {
                    var trimmedAnswer = ragResponse.Answer.TrimStart();
                    
                    // CRITICAL FIX: When LLM returns: {"answer": "{\n  \"answer\":...", "chartData": null}
                    // The C# string contains literal backslash-n (\n) and backslash-quote (\")
                    // Use Regex.Unescape which converts these to actual newlines and quotes
                    if (trimmedAnswer.StartsWith("{"))
                    {
                        _logger.LogWarning("ChartData is null but answer starts with {{. Attempting to unescape and parse nested JSON. Answer preview: {Preview}", trimmedAnswer.Substring(0, Math.Min(100, trimmedAnswer.Length)));
                        
                        // Use Regex.Unescape to convert \n -> newline, \" -> quote, etc.
                        try
                        {
                            var unescapedJson = System.Text.RegularExpressions.Regex.Unescape(trimmedAnswer);
                            _logger.LogInformation("Unescaped JSON preview: {Preview}", unescapedJson.Substring(0, Math.Min(100, unescapedJson.Length)));
                            
                            var nestedResponse = JsonSerializer.Deserialize<RagResponse>(unescapedJson, new JsonSerializerOptions
                            {
                                PropertyNameCaseInsensitive = true
                            });
                            
                            if (nestedResponse != null && nestedResponse.ChartData != null)
                            {
                                ragResponse = nestedResponse;
                                _logger.LogInformation("Successfully extracted nested JSON via Regex.Unescape");
                                return ragResponse;
                            }
                            else
                            {
                                _logger.LogWarning("Regex.Unescape succeeded but chartData still null");
                            }
                        }
                        catch (Exception unescapeEx)
                        {
                            _logger.LogWarning("Regex.Unescape failed: {Error}", unescapeEx.Message);
                        }
                    }
                }
                
                _logger.LogInformation("Successfully parsed RAG response");
            }
            catch (JsonException ex)
            {
                _logger.LogWarning("JSON parsing failed: {Error}. Attempting fallback parsing.", ex.Message);
                
                // Fallback: The LLM might have returned the JSON object as a string in the answer field
                // Try to extract and parse it
                try
                {
                    // Check if the response starts with { - it might be valid JSON without wrapper
                    if (cleanedResponse.StartsWith("{"))
                    {
                        // Try parsing directly
                        var directParse = JsonSerializer.Deserialize<RagResponse>(cleanedResponse, new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });
                        
                        if (directParse != null)
                        {
                            ragResponse = directParse;
                            _logger.LogInformation("Successfully parsed response on second attempt");
                        }
                        else
                        {
                            throw new JsonException("Direct parse returned null");
                        }
                    }
                    else
                    {
                        // Use raw response as answer
                        ragResponse = new RagResponse 
                        { 
                            Answer = responseContent,
                            Success = true
                        };
                        _logger.LogWarning("Using raw response as fallback");
                    }
                }
                catch
                {
                    // Final fallback: use raw response
                    ragResponse = new RagResponse 
                    { 
                        Answer = responseContent,
                        Success = true
                    };
                    _logger.LogWarning("All parsing attempts failed, using raw response");
                }
            }

            ragResponse.Success = true;
            ragResponse.SourceDocuments = rankedDocs.Take(3).ToList();
            ragResponse.TokensUsed = llmResponse.Usage?.TotalTokens ?? 0;

            _logger.LogInformation("RAG query completed successfully");
            return ragResponse;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process RAG query");
            return new RagResponse
            {
                Answer = $"An error occurred while processing your question: {ex.Message}",
                Success = false
            };
        }
    }

    private bool IsPredictiveQuery(string question)
    {
        var lowerQuestion = question.ToLower();
        var predictiveKeywords = new[]
        {
            "predict", "forecast", "future", "estimate", "projection",
            "expected", "anticipated", "trend", "will be", "going to be",
            "next year", "next month", "next quarter", "2010", "2011", "2012",
            "based on", "historical", "past years"
        };

        return predictiveKeywords.Any(keyword => lowerQuestion.Contains(keyword));
    }

    private string GetStandardSystemPrompt()
    {
        return @"You are a sales data analyst. Analyze the provided sales data and answer the user's question with CONSISTENT and ACCURATE results.

IMPORTANT: The context includes a DATE RANGE header showing the time period covered. All data in the context is from that specific time period.

CRITICAL INSTRUCTIONS:
1. Base your chart data ONLY on the exact data provided in the context
2. The context header shows the date range - use this to understand what time period the data covers
3. If asked meta-questions about data availability, refer to the date range in the context
4. Use the SAME aggregation method every time for the same type of question
5. Sort data consistently (e.g., always by value descending for top products)
6. Round numbers to 2 decimal places for consistency
7. Limit chart data to top 5-10 items for clarity

Your response MUST be a valid JSON object with this exact structure:
{
  ""answer"": ""Your detailed narrative answer here"",
  ""chartData"": {
    ""chartType"": ""bar or line or pie"",
    ""title"": ""Chart title"",
    ""labels"": [""Label1"", ""Label2""],
    ""values"": [value1, value2]
  }
}

CRITICAL: Return ONLY the raw JSON object. DO NOT wrap in markdown code blocks (```json or ```)

Chart Type Guidelines:
- Use 'bar' for comparisons (products, categories, manufacturers)
- Use 'line' for time series or trends
- Use 'pie' for proportions/percentages (max 5-6 categories)

Always include both 'answer' and 'chartData'. Make sure the JSON is valid and parseable.";
    }

    private string GetPredictiveSystemPrompt()
    {
        return @"You are an expert sales data analyst with forecasting capabilities. Analyze the provided HISTORICAL sales data and make predictions based on trends.

FORECASTING INSTRUCTIONS:
1. Identify trends in the historical data (growth rate, seasonality, patterns)
2. Calculate year-over-year growth rates or monthly patterns
3. Apply simple linear regression or trend extrapolation
4. Make reasonable predictions based on historical patterns
5. Clearly state assumptions and confidence levels
6. Use 'line' chart type to show historical data + predictions

Your response MUST be a valid JSON object with this exact structure:
{
  ""answer"": ""Your detailed forecast answer including methodology, trends observed, and predicted values with confidence levels"",
  ""chartData"": {
    ""chartType"": ""line"",
    ""title"": ""Historical Sales & Forecast"",
    ""labels"": [""2007"", ""2008"", ""2009"", ""2010 (Predicted)""],
    ""values"": [actual1, actual2, actual3, predicted1]
  }
}

CRITICAL:
- Return ONLY the raw JSON object, NO markdown code blocks or formatting
- DO NOT wrap the response in ```json or ``` markers 
- Show historical data AND predictions in the chart
- Clearly label which data points are historical vs predicted
- Explain your forecasting methodology in the answer
- Be transparent about limitations (e.g., 'Based on available data from 2007-2009...')
- Round predictions to 2 decimal places

Always include both 'answer' and 'chartData'. Make sure the JSON is valid and parseable.";
    }

    private string BuildUserPrompt(string question, string context, bool isPredictive)
    {
        if (isPredictive)
        {
            return $@"Question: {question}

Historical Sales Data (Time Series):
{context}

FORECASTING TASK:
1. Analyze the historical trends in the data above
2. Calculate growth rates, identify patterns, and seasonality
3. Apply trend extrapolation or simple linear regression
4. Make a reasonable prediction for the requested future period
5. Explain your methodology and confidence level
6. Create a line chart showing both historical data and predictions

IMPORTANT:
- Be explicit about what data you're using for the forecast
- Show your calculations and assumptions
- Label predicted values clearly in the chart
- Provide a confidence range if possible (e.g., 'predicted $X, with range of $Y-$Z')

Return ONLY the JSON response, nothing else.";
        }
        else
        {
            return $@"Question: {question}

Sales Data Context (sorted by relevance):
{context}

IMPORTANT: 
- Aggregate the data consistently
- If asked for 'top N', always sort by the metric descending and take exactly N items
- Use the same calculation method every time
- Round all monetary values to 2 decimal places
- For time-based queries, maintain chronological order

Please analyze this data and provide:
1. A clear narrative answer to the question with specific numbers
2. Chart data that accurately visualizes the key insights (choose appropriate chart type)

Return ONLY the JSON response, nothing else.";
        }
    }

    private string BuildTimeSeriesContext(List<ProductSalesEnriched> documents)
    {
        var contextBuilder = new System.Text.StringBuilder();
        
        // Group by year and month for time series analysis
        var timeSeriesData = documents
            .GroupBy(d => new { Year = d.DateKey.Year, Month = d.DateKey.Month })
            .Select(g => new
            {
                Period = $"{g.Key.Year}-{g.Key.Month:D2}",
                Year = g.Key.Year,
                Month = g.Key.Month,
                TotalSales = g.Sum(d => d.NetSalesAmount),
                TotalQuantity = g.Sum(d => d.SalesQuantity),
                AvgProfitMargin = g.Average(d => d.ProfitMargin),
                TransactionCount = g.Count()
            })
            .OrderBy(x => x.Year)
            .ThenBy(x => x.Month)
            .ToList();

        contextBuilder.AppendLine("TIME SERIES DATA (Monthly Aggregations):");
        contextBuilder.AppendLine("===========================================");
        
        foreach (var item in timeSeriesData)
        {
            contextBuilder.AppendLine($"Period: {item.Period} ({item.Year} Month {item.Month})");
            contextBuilder.AppendLine($"  Total Sales: ${item.TotalSales:F2}");
            contextBuilder.AppendLine($"  Total Quantity: {item.TotalQuantity} units");
            contextBuilder.AppendLine($"  Average Profit Margin: {item.AvgProfitMargin:F1}%");
            contextBuilder.AppendLine($"  Transactions: {item.TransactionCount}");
            contextBuilder.AppendLine();
        }

        // Add yearly summaries for easier trend analysis
        var yearlyData = documents
            .GroupBy(d => d.DateKey.Year)
            .Select(g => new
            {
                Year = g.Key,
                TotalSales = g.Sum(d => d.NetSalesAmount),
                TotalQuantity = g.Sum(d => d.SalesQuantity),
                AvgProfitMargin = g.Average(d => d.ProfitMargin)
            })
            .OrderBy(x => x.Year)
            .ToList();

        contextBuilder.AppendLine();
        contextBuilder.AppendLine("YEARLY SUMMARIES:");
        contextBuilder.AppendLine("=================");
        
        foreach (var item in yearlyData)
        {
            contextBuilder.AppendLine($"Year: {item.Year}");
            contextBuilder.AppendLine($"  Total Annual Sales: ${item.TotalSales:F2}");
            contextBuilder.AppendLine($"  Total Annual Quantity: {item.TotalQuantity} units");
            contextBuilder.AppendLine($"  Average Profit Margin: {item.AvgProfitMargin:F1}%");
            contextBuilder.AppendLine();
        }

        // Calculate growth rates if we have multiple years
        if (yearlyData.Count > 1)
        {
            contextBuilder.AppendLine("YEAR-OVER-YEAR GROWTH RATES:");
            contextBuilder.AppendLine("=============================");
            
            for (int i = 1; i < yearlyData.Count; i++)
            {
                var current = yearlyData[i];
                var previous = yearlyData[i - 1];
                var growthRate = ((current.TotalSales - previous.TotalSales) / previous.TotalSales) * 100;
                
                contextBuilder.AppendLine($"{previous.Year} to {current.Year}: {growthRate:F2}% growth");
                contextBuilder.AppendLine($"  Previous: ${previous.TotalSales:F2} → Current: ${current.TotalSales:F2}");
                contextBuilder.AppendLine();
            }
        }

        return contextBuilder.ToString();
    }

    private List<ProductSalesEnriched> ReRankDocuments(List<ProductSalesEnriched> documents, string question)
    {
        // Implement a simple relevance-based reranking
        var lowerQuestion = question.ToLower();
        
        // Score documents based on multiple factors
        var scoredDocs = documents.Select(doc => new
        {
            Document = doc,
            Score = CalculateRelevanceScore(doc, lowerQuestion)
        })
        .OrderByDescending(x => x.Score)
        .ThenByDescending(x => x.Document.NetSalesAmount) // Secondary sort by sales amount
        .Select(x => x.Document)
        .Distinct() // Remove duplicates
        .Take(5) // Limit to top 5 most relevant
        .ToList();

        return scoredDocs;
    }

    private double CalculateRelevanceScore(ProductSalesEnriched doc, string lowerQuestion)
    {
        double score = 0;

        // Keyword matching
        var keywords = new[] { 
            doc.ProductName.ToLower(), 
            doc.Manufacturer.ToLower(), 
            doc.BrandName.ToLower(),
            doc.ClassName.ToLower()
        };

        foreach (var keyword in keywords)
        {
            if (lowerQuestion.Contains(keyword))
            {
                score += 10;
            }
        }

        // Date relevance (prefer more recent data)
        var daysSinceTransaction = (DateTime.Now - doc.DateKey).TotalDays;
        score += Math.Max(0, 5 - (daysSinceTransaction / 365)); // Bonus for newer data

        // Sales amount (higher sales = more important)
        score += Math.Log10(Math.Max(1, doc.NetSalesAmount)) * 2;

        // Profit margin (prefer profitable products)
        score += Math.Max(0, doc.ProfitMargin / 10);

        return score;
    }

    private string? ExtractDateFilter(string query)
    {
        // Simple date extraction - matches patterns like "November 2007", "2007", "Jan 2008"
        var lowerQuery = query.ToLower();
        
        // Match year patterns
        var yearMatch = System.Text.RegularExpressions.Regex.Match(query, @"\b(20\d{2})\b");
        if (!yearMatch.Success) return null;
        
        var year = int.Parse(yearMatch.Value);
        
        // Match month names
        var monthNames = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
        {
            {"january", 1}, {"jan", 1}, {"february", 2}, {"feb", 2}, {"march", 3}, {"mar", 3},
            {"april", 4}, {"apr", 4}, {"may", 5}, {"june", 6}, {"jun", 6}, {"july", 7}, {"jul", 7},
            {"august", 8}, {"aug", 8}, {"september", 9}, {"sep", 9}, {"october", 10}, {"oct", 10},
            {"november", 11}, {"nov", 11}, {"december", 12}, {"dec", 12}
        };
        
        int? month = null;
        foreach (var kvp in monthNames)
        {
            if (lowerQuery.Contains(kvp.Key))
            {
                month = kvp.Value;
                break;
            }
        }
        
        if (month.HasValue)
        {
            // Filter for specific month and year
            var startDate = new DateTime(year, month.Value, 1);
            var endDate = startDate.AddMonths(1);
            return $"DateKey ge {startDate:yyyy-MM-ddTHH:mm:ssZ} and DateKey lt {endDate:yyyy-MM-ddTHH:mm:ssZ}";
        }
        else
        {
            // Filter for entire year
            var startDate = new DateTime(year, 1, 1);
            var endDate = new DateTime(year + 1, 1, 1);
            return $"DateKey ge {startDate:yyyy-MM-ddTHH:mm:ssZ} and DateKey lt {endDate:yyyy-MM-ddTHH:mm:ssZ}";
        }
    }

    private string BuildContext(List<ProductSalesEnriched> documents)
    {
        var contextBuilder = new System.Text.StringBuilder();
        
        // Add date range information
        if (documents.Any())
        {
            var minDate = documents.Min(d => d.DateKey);
            var maxDate = documents.Max(d => d.DateKey);
            contextBuilder.AppendLine("=== DATA TIME PERIOD ===");
            contextBuilder.AppendLine($"Date Range: {minDate:yyyy-MM-dd} to {maxDate:yyyy-MM-dd}");
            contextBuilder.AppendLine($"This dataset contains {documents.Count} sales transactions");
            contextBuilder.AppendLine();
        }
        
        // Group by product to reduce redundancy
        var groupedDocs = documents
            .GroupBy(d => new { d.ProductKey, d.ProductName })
            .Select(g => new
            {
                Product = g.First(),
                TotalSales = g.Sum(d => d.NetSalesAmount),
                TotalQuantity = g.Sum(d => d.SalesQuantity),
                AvgProfitMargin = g.Average(d => d.ProfitMargin),
                TransactionCount = g.Count(),
                DateRange = $"{g.Min(d => d.DateKey):yyyy-MM-dd} to {g.Max(d => d.DateKey):yyyy-MM-dd}"
            })
            .OrderByDescending(x => x.TotalSales)
            .ToList();

        contextBuilder.AppendLine("=== PRODUCT SALES SUMMARY ===");
        foreach (var item in groupedDocs)
        {
            contextBuilder.AppendLine($"Product: {item.Product.ProductName}");
            contextBuilder.AppendLine($"  Manufacturer: {item.Product.Manufacturer} ({item.Product.BrandName})");
            contextBuilder.AppendLine($"  Category: {item.Product.ClassName}, Color: {item.Product.ColorName}");
            contextBuilder.AppendLine($"  Transaction Dates: {item.DateRange}");
            contextBuilder.AppendLine($"  Total Net Sales: ${item.TotalSales:F2}");
            contextBuilder.AppendLine($"  Total Quantity Sold: {item.TotalQuantity} units");
            contextBuilder.AppendLine($"  Average Profit Margin: {item.AvgProfitMargin:F1}%");
            contextBuilder.AppendLine($"  Number of Transactions: {item.TransactionCount}");
            contextBuilder.AppendLine();
        }

        return contextBuilder.ToString();
    }
}

public class RagResponse
{
    public string Answer { get; set; } = string.Empty;
    public ChartData? ChartData { get; set; }
    public bool Success { get; set; }
    public List<ProductSalesEnriched>? SourceDocuments { get; set; }
    public int TokensUsed { get; set; }
}

public class ChartData
{
    public string ChartType { get; set; } = "bar";
    public string Title { get; set; } = string.Empty;
    public List<string> Labels { get; set; } = new();
    public List<decimal?> Values { get; set; } = new();
}
