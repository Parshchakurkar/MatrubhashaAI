using MatrubhashaAI.Models;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Net.Http.Headers;
using System.Text;
using System.Text.RegularExpressions;

namespace MatrubhashaAI.Controllers
{

    public class TranslationController : Controller
    {
        private readonly IHttpClientFactory _httpClientFactory;

        public TranslationController(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory = httpClientFactory;
        }

        [HttpGet]
        public IActionResult Index()
        {
            return View();
        }

        [HttpPost]
        [Route("Translation/TranslateWithGoogle")]
        public async Task<IActionResult> TranslateWithGoogle([FromBody] GoogleTranslationRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Content) || string.IsNullOrWhiteSpace(request.TargetLanguage))
                return BadRequest(new { success = false, error = "Content and Target Language are required." });

            try
            {
                var httpClient = _httpClientFactory.CreateClient();
                var apiKey = "AIzaSyDbSk0gXd0g4lEfHOHWUXYCvC90RPp6VqE"; // Secure this key in appsettings or env variable

                var url = $"https://translation.googleapis.com/language/translate/v2?key={apiKey}";
                var body = new
                {
                    q = request.Content,
                    target = request.TargetLanguage,
                    format = "text"
                };

                var content = new StringContent(JsonConvert.SerializeObject(body), Encoding.UTF8, "application/json");
                var response = await httpClient.PostAsync(url, content);
                var json = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                    return BadRequest(new { success = false, error = $"Google Translate API Error: {json}" });

                dynamic? result = JsonConvert.DeserializeObject(json);
                string translatedText = result?.data?.translations[0]?.translatedText ?? "Translation not available.";

                return Ok(new { success = true, translation = translatedText });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, error = $"Server Error: {ex.Message}" });
            }
        }

        [HttpPost("Translation/ExtractFromUrl")]

        public async Task<IActionResult> ExtractFromUrl([FromBody] UrlRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Url))
                return BadRequest(new { success = false, error = "URL is required." });

            try
            {
                using var handler = new HttpClientHandler
                {
                    AllowAutoRedirect = true
                };

                using var client = new HttpClient(handler);
                client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

                var html = await client.GetStringAsync(request.Url);

                // Extract content from readable tags (p, h1-h3)
                var matches = Regex.Matches(html, @"<(p|h1|h2|h3)[^>]*>(.*?)<\/\1>", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var textBlocks = matches
                    .Cast<Match>()
                    .Select(m => Regex.Replace(m.Groups[2].Value, "<.*?>", "")) // Remove nested tags
                    .Select(text => System.Net.WebUtility.HtmlDecode(text.Trim()))
                    .Where(text => !string.IsNullOrWhiteSpace(text))
                    .ToList();

                var plainText = string.Join("\n\n", textBlocks);

                return Ok(new { success = true, content = plainText });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, error = $"Error extracting from URL: {ex.Message}" });
            }
        }

        //public async Task<IActionResult> ExtractFromUrl([FromBody] UrlRequest request)
        //{
        //    if (string.IsNullOrWhiteSpace(request.Url))
        //        return BadRequest(new { success = false, error = "URL is required." });

        //    //try
        //    //{
        //    //    using var client = new HttpClient();
        //    //    var html = await client.GetStringAsync(request.Url);

        //    //    // Extract all <p> tag content
        //    //    var matches = Regex.Matches(html, @"<p.*?>(.*?)<\/p>", RegexOptions.Singleline);
        //    //    var paragraphs = matches
        //    //        .Cast<Match>()
        //    //        .Select(m => Regex.Replace(m.Groups[1].Value, "<.*?>", "").Trim())
        //    //        .Where(text => !string.IsNullOrWhiteSpace(text))
        //    //        .ToList();

        //    //    var content = string.Join("\n\n", paragraphs);

        //    //    return Ok(new { success = true, content });
        //    //}
        //    try
        //    {
        //        using var client = new HttpClient();
        //        client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

        //        var html = await client.GetStringAsync(request.Url);

        //        // Extract all <p> tags
        //        var matches = Regex.Matches(html, @"<p.*?>(.*?)<\/p>", RegexOptions.Singleline);
        //        var paragraphs = matches
        //            .Cast<Match>()
        //            .Select(m => Regex.Replace(m.Groups[1].Value, "<.*?>", "").Trim())
        //            .Where(text => !string.IsNullOrWhiteSpace(text))
        //            .ToList();

        //        var content = string.Join("\n\n", paragraphs);

        //        return Ok(new { success = true, content });
        //    }
        //    catch (Exception ex)
        //    {
        //        return StatusCode(500, new { success = false, error = $"Error extracting from URL: {ex.Message}" });
        //    }
        //}


    }


}
