using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace ProductSales.Services;

public interface IEmbeddingService
{
    float[] GetEmbedding(string text);
    Task<float[]> GetEmbeddingAsync(string text);
    ReadOnlyMemory<float> GetEmbeddingMemory(string text);
}

public class EmbeddingService : IEmbeddingService, IDisposable
{
    private readonly InferenceSession _session;
    private readonly ILogger<EmbeddingService> _logger;
    private readonly int _maxTokens = 256;

    public EmbeddingService(IConfiguration configuration, ILogger<EmbeddingService> logger)
    {
        _logger = logger;
        
        // Path to ONNX model - placed in Models/ directory (case-sensitive on Linux)
        var modelPath = configuration["Embedding:ModelPath"] 
            ?? Path.Combine(AppContext.BaseDirectory, "Models", "all-MiniLM-L6-v2.onnx");
        
        if (!File.Exists(modelPath))
        {
            throw new FileNotFoundException(
                $"ONNX model not found at {modelPath}. " +
                "Please download all-MiniLM-L6-v2 model and place it in the Models directory. " +
                "Download from: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2");
        }

        _logger.LogInformation("Loading ONNX model from: {ModelPath}", modelPath);
        _session = new InferenceSession(modelPath);
        
        _logger.LogInformation("EmbeddingService initialized successfully");
    }

    public float[] GetEmbedding(string text)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                return new float[384]; // Return zero vector for empty text
            }

            // Tokenize text
            var encoded = TokenizeText(text);
            
            // Prepare input tensors
            var inputIds = new DenseTensor<long>(encoded.InputIds, new[] { 1, encoded.InputIds.Length });
            var attentionMask = new DenseTensor<long>(encoded.AttentionMask, new[] { 1, encoded.AttentionMask.Length });
            var tokenTypeIds = new DenseTensor<long>(encoded.TokenTypeIds, new[] { 1, encoded.TokenTypeIds.Length });

            var inputs = new List<NamedOnnxValue>
            {
                NamedOnnxValue.CreateFromTensor("input_ids", inputIds),
                NamedOnnxValue.CreateFromTensor("attention_mask", attentionMask),
                NamedOnnxValue.CreateFromTensor("token_type_ids", tokenTypeIds)
            };

            // Run inference
            using var results = _session.Run(inputs);
            var outputTensor = results.First().AsTensor<float>();

            // Extract embeddings (mean pooling)
            var embeddings = MeanPooling(outputTensor, encoded.AttentionMask);

            // Normalize
            return Normalize(embeddings);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate embedding for text: {Text}", 
                text.Length > 100 ? text.Substring(0, 100) + "..." : text);
            return new float[384]; // Return zero vector on error
        }
    }

    public async Task<float[]> GetEmbeddingAsync(string text)
    {
        // ONNX Runtime is synchronous, but we provide async signature for API consistency
        return await Task.Run(() => GetEmbedding(text));
    }

    public ReadOnlyMemory<float> GetEmbeddingMemory(string text)
    {
        return new ReadOnlyMemory<float>(GetEmbedding(text));
    }

    private (long[] InputIds, long[] AttentionMask, long[] TokenTypeIds) TokenizeText(string text)
    {
        // Simplified tokenization - in production, use proper BERT tokenizer
        // For now, using basic word splitting and padding
        var words = text.ToLower()
            .Split(new[] { ' ', '\t', '\n', '\r', '.', ',', '!', '?', ';', ':' }, 
                   StringSplitOptions.RemoveEmptyEntries);

        var inputIds = new List<long> { 101 }; // [CLS] token
        var attentionMask = new List<long> { 1 };
        var tokenTypeIds = new List<long> { 0 }; // All zeros for single sentence

        foreach (var word in words.Take(_maxTokens - 2)) // Reserve space for [CLS] and [SEP]
        {
            // Simple hash-based token ID (placeholder for real tokenizer)
            var tokenId = Math.Abs(word.GetHashCode()) % 30000 + 1000;
            inputIds.Add(tokenId);
            attentionMask.Add(1);
            tokenTypeIds.Add(0);
        }

        inputIds.Add(102); // [SEP] token
        attentionMask.Add(1);
        tokenTypeIds.Add(0);

        // Pad to max length
        while (inputIds.Count < _maxTokens)
        {
            inputIds.Add(0);
            attentionMask.Add(0);
            tokenTypeIds.Add(0);
        }

        return (inputIds.ToArray(), attentionMask.ToArray(), tokenTypeIds.ToArray());
    }

    private float[] MeanPooling(Tensor<float> embeddings, long[] attentionMask)
    {
        // embeddings shape: [batch_size, sequence_length, hidden_size]
        // For all-MiniLM-L6-v2: [1, seq_len, 384]
        
        var batchSize = embeddings.Dimensions[0];
        var seqLength = embeddings.Dimensions[1];
        var hiddenSize = embeddings.Dimensions[2];

        var pooled = new float[hiddenSize];
        var maskSum = 0;

        for (int i = 0; i < seqLength; i++)
        {
            if (attentionMask[i] == 1)
            {
                for (int j = 0; j < hiddenSize; j++)
                {
                    pooled[j] += embeddings[0, i, j];
                }
                maskSum++;
            }
        }

        // Average
        if (maskSum > 0)
        {
            for (int i = 0; i < hiddenSize; i++)
            {
                pooled[i] /= maskSum;
            }
        }

        return pooled;
    }

    private float[] Normalize(float[] vector)
    {
        var norm = Math.Sqrt(vector.Sum(v => v * v));
        if (norm > 0)
        {
            for (int i = 0; i < vector.Length; i++)
            {
                vector[i] /= (float)norm;
            }
        }
        return vector;
    }

    public void Dispose()
    {
        _session?.Dispose();
    }
}
