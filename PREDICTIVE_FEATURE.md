# Predictive Analytics Feature

## Overview

The RAG application now supports **predictive/forecasting queries** in addition to historical data analysis. The system can analyze historical trends and make reasonable predictions about future sales.

---

## How It Works

### Detection
The system automatically detects predictive queries by looking for keywords:
- `predict`, `forecast`, `future`, `estimate`, `projection`
- `expected`, `anticipated`, `trend`, `will be`
- `next year`, `next month`, `next quarter`
- Future year references (2010, 2011, etc.)
- `based on`, `historical`, `past years`

### Process Flow

**For Predictive Queries:**
1. **Retrieve More Data:** Fetches 50 documents instead of 10 (needs more historical context)
2. **Time-Series Aggregation:** Groups data by year/month
3. **Trend Calculation:** Calculates year-over-year growth rates
4. **Specialized Prompt:** Uses forecasting-specific instructions for the LLM
5. **Prediction Generation:** LLM applies trend analysis or linear regression
6. **Visual Forecast:** Returns line chart showing historical + predicted values

**For Regular Queries:**
- Standard retrieval (10 documents)
- Product/category grouping
- Basic aggregation and sorting

---

## Example Queries

### Predictive Queries ✨

```
"Based on historical trends, what are predicted sales for 2010?"
"What is the sales forecast for next year?"
"Predict future sales based on the past 3 years"
"Based on 2007-2009 data, estimate 2010 revenue"
"What will sales be in November 2010?"
"Forecast sales growth for the next quarter"
```

### Historical Queries 📊

```
"What were the total sales in November 2007?"
"Show me the top 5 products by profit margin"
"Compare sales by manufacturer in 2008"
"What is the average discount amount?"
```

---

## Technical Implementation

### Backend Changes

**File:** `Services/RagService.cs`

#### 1. Query Detection
```csharp
private bool IsPredictiveQuery(string question)
{
    var predictiveKeywords = new[]
    {
        "predict", "forecast", "future", "estimate",
        "projection", "expected", "anticipated", "trend"
    };
    return predictiveKeywords.Any(keyword => 
        question.ToLower().Contains(keyword));
}
```

#### 2. Time-Series Context Building
```csharp
private string BuildTimeSeriesContext(List<ProductSalesEnriched> documents)
{
    // Groups by Year/Month
    // Calculates monthly aggregates
    // Provides yearly summaries
    // Computes year-over-year growth rates
}
```

**Output includes:**
- Monthly sales totals
- Yearly aggregations
- Growth rate calculations
- Transaction volumes

#### 3. Specialized Prompts

**Predictive System Prompt:**
- Instructions for trend analysis
- Methodology guidance (linear regression, extrapolation)
- Chart formatting (historical + predictions)
- Transparency requirements (assumptions, confidence levels)

**Predictive User Prompt:**
- Historical time-series data
- Growth rate calculations
- Instructions to show methodology
- Chart labeling requirements

### Frontend Changes

**File:** `components/ResultDisplay.js`

#### Visual Indicators
- 🔮 Icon for predictive analyses
- "📊 Predictive Analysis" badge
- Warning notice about forecast limitations
- Glowing animation effect

**File:** `components/QueryInput.js`

#### Sample Questions
Added predictive query examples to help users discover the feature.

---

## Forecasting Methodology

The LLM is instructed to use:

### 1. Trend Extrapolation
- Calculate average growth rate
- Apply to future periods
- Simple but effective for stable trends

### 2. Linear Regression (Conceptual)
- Fit line to historical data points
- Extend line into future
- Better for consistent linear trends

### 3. Seasonality Detection
- Identify monthly/quarterly patterns
- Apply patterns to future periods
- Useful for cyclical businesses

### Limitations & Transparency

The system explicitly:
- States which historical data is used
- Explains the methodology applied
- Provides confidence levels when possible
- Warns about limitations
- Labels predicted vs actual data clearly

---

## Response Format

### Predictive Response Example

```json
{
  "answer": "Based on sales data from 2007-2009, I analyzed the year-over-year growth trend. Sales grew from $2.5M (2007) to $3.1M (2008), a 24% increase, and then to $3.8M (2009), a 23% increase. Using trend extrapolation with an average growth rate of 23.5%, the predicted sales for 2010 would be approximately $4.69M. This assumes the growth trend continues without major market disruptions. Confidence: Moderate, based on 3 years of data.",
  
  "chartData": {
    "chartType": "line",
    "title": "Historical Sales & 2010 Forecast",
    "labels": ["2007", "2008", "2009", "2010 (Predicted)"],
    "values": [2500000, 3100000, 3800000, 4690000]
  },
  
  "success": true,
  "tokensUsed": 850
}
```

### Chart Visualization
- Line chart showing trend
- Historical data points (solid)
- Predicted data points (can be distinguished in the answer)
- Clear labels

---

## UI Features

### Predictive Indicator
When a forecast is detected:
- Header changes to "🔮 AI Forecast & Analysis"
- Pink glowing badge: "📊 Predictive Analysis"
- Yellow warning box: "⚠️ Note: This is a forecast based on historical trends..."

### Regular Analysis
- Header: "💡 AI Analysis"
- No special badges
- Standard display

---

## Best Practices

### For Users

**Do:**
- ✅ Ask about specific metrics (sales, quantity, profit)
- ✅ Specify time ranges ("based on 2007-2009")
- ✅ Request methodology explanation
- ✅ Ask for confidence levels

**Don't:**
- ❌ Expect perfect predictions (it's an estimate)
- ❌ Ask about distant future (e.g., 2020 from 2007-2009 data)
- ❌ Ignore the limitations stated in the response
- ❌ Use for critical business decisions without validation

### Sample Data Coverage

**Available Data:** 2007-2009 (Contoso Retail dataset)

**Good Predictions:**
- 2010 (1 year ahead) ✅
- 2011 (2 years ahead) ⚠️ Less reliable
- 2012+ (3+ years) ❌ Too speculative

---

## Configuration

### Adjusting Retrieval Size

In `RagService.cs`:
```csharp
var topResults = isPredictiveQuery ? 50 : 10;
```

**Trade-offs:**
- More data = Better trend analysis, higher token cost
- Less data = Faster, cheaper, might miss patterns

### Adding Keywords

To detect more prediction queries, edit:
```csharp
private bool IsPredictiveQuery(string question)
{
    var predictiveKeywords = new[]
    {
        // Add your keywords here
        "predict", "forecast", "future"
    };
}
```

---

## Limitations

### Current Limitations

1. **Simple Forecasting:** Linear trends only, no advanced models
2. **LLM-Dependent:** Accuracy depends on LLM reasoning
3. **Data Requirements:** Needs sufficient historical data
4. **No ML Models:** Not using specialized forecasting libraries
5. **No Validation:** Predictions aren't validated against actual data

### Future Enhancements

1. **Statistical Models:** Integrate ARIMA, Prophet, or similar
2. **Confidence Intervals:** Calculate statistical confidence ranges
3. **Multiple Scenarios:** Best/worst/likely case predictions
4. **Validation Metrics:** MAPE, RMSE for historical accuracy
5. **Seasonality Detection:** Advanced pattern recognition
6. **External Factors:** Consider market conditions, holidays, etc.

---

## Testing

### Test Scenarios

1. **Simple Forecast:**
   ```
   "What will sales be in 2010 based on past trends?"
   ```
   Expected: Growth rate calculation + prediction

2. **Specific Product:**
   ```
   "Predict A. Datum camera sales for next year"
   ```
   Expected: Product-specific forecast

3. **Comparison:**
   ```
   "Compare 2009 actual vs 2010 predicted sales"
   ```
   Expected: Side-by-side comparison with methodology

4. **Edge Case - No Data:**
   ```
   "Predict sales for 2020"
   ```
   Expected: Explanation that it's too far ahead

---

## Summary

The predictive analytics feature extends your RAG application beyond historical analysis to include forecasting capabilities. It:

- ✅ Automatically detects predictive queries
- ✅ Provides time-series aggregated context
- ✅ Instructs LLM to perform trend analysis
- ✅ Generates visual forecasts with line charts
- ✅ Includes transparency and limitations
- ✅ Shows clear UI indicators for predictions

**Restart the backend** to enable this feature and try the sample predictive questions! 🚀
