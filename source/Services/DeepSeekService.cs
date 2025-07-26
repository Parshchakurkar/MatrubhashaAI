using System.Text;
using System.Text.Json;

public class DeepSeekService
{
	private readonly HttpClient _httpClient;
	private const string ApiBaseUrl = "https://api.deepseek.com/v1/chat/completions"; // Check actual API endpoint

	public DeepSeekService(HttpClient httpClient)
	{
		_httpClient = httpClient;
		_httpClient.DefaultRequestHeaders.Add("Authorization", "Bearer YOUR_API_KEY"); // Replace with actual key
	}

	public async Task<string> TranslateTextAsync(string text, string targetLanguage)
	{
		var request = new
		{
			model = "deepseek-chat", // Confirm model name
			messages = new[]
			{
				new
				{
					role = "user",
					content = $"Translate this to {targetLanguage}:\n\n{text}"
				}
			},
			temperature = 0.3 // For more consistent translations
		};

		var json = JsonSerializer.Serialize(request);
		var content = new StringContent(json, Encoding.UTF8, "application/json");

		var response = await _httpClient.PostAsync(ApiBaseUrl, content);
		response.EnsureSuccessStatusCode();

		var responseJson = await response.Content.ReadAsStringAsync();
		using var doc = JsonDocument.Parse(responseJson);

		return doc.RootElement
			.GetProperty("choices")[0]
			.GetProperty("message")
			.GetProperty("content")
			.GetString();
	}
}