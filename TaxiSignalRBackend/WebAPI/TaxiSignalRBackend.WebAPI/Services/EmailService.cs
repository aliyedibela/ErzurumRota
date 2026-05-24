using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace TaxiSignalRBackend.WebAPI.Services
{
    public class EmailService
    {
        // Credentials Railway dashboard'daki env var'lardan okunur
        private static string ClientId     => Environment.GetEnvironmentVariable("GMAIL_CLIENT_ID")     ?? "";
        private static string ClientSecret => Environment.GetEnvironmentVariable("GMAIL_CLIENT_SECRET") ?? "";
        private static string RefreshToken => Environment.GetEnvironmentVariable("GMAIL_REFRESH_TOKEN") ?? "";
        private const  string GmailUser    = "erzurumbbappetu@gmail.com";

        public async Task SendVerificationEmail(string toEmail, string code)
        {
            // 1) Refresh token → access token
            var accessToken = await GetAccessTokenAsync();

            // 2) RFC 2822 formatında email oluştur
            var raw = $"From: Erzurum BB App <{GmailUser}>\r\n" +
                      $"To: {toEmail}\r\n" +
                      $"Subject: Doğrulama Kodunuz\r\n" +
                      $"MIME-Version: 1.0\r\n" +
                      $"Content-Type: text/html; charset=utf-8\r\n\r\n" +
                      BuildHtml(code);

            var base64Url = Convert.ToBase64String(Encoding.UTF8.GetBytes(raw))
                .Replace('+', '-').Replace('/', '_').TrimEnd('=');

            // 3) Gmail API ile gönder
            using var http = new HttpClient();
            http.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", accessToken);

            var payload = JsonSerializer.Serialize(new { raw = base64Url });
            var content = new StringContent(payload, Encoding.UTF8, "application/json");

            var response = await http.PostAsync(
                $"https://gmail.googleapis.com/gmail/v1/users/{GmailUser}/messages/send",
                content);

            if (!response.IsSuccessStatusCode)
            {
                var err = await response.Content.ReadAsStringAsync();
                throw new Exception($"Gmail API hatası: {response.StatusCode} — {err}");
            }

            Console.WriteLine($"✅ Gmail API ile email gönderildi: {toEmail}");
        }

        private static async Task<string> GetAccessTokenAsync()
        {
            using var http = new HttpClient();
            var form = new FormUrlEncodedContent(new[]
            {
                new KeyValuePair<string,string>("client_id",     ClientId),
                new KeyValuePair<string,string>("client_secret", ClientSecret),
                new KeyValuePair<string,string>("refresh_token", RefreshToken),
                new KeyValuePair<string,string>("grant_type",    "refresh_token"),
            });

            var res  = await http.PostAsync("https://oauth2.googleapis.com/token", form);
            var json = await res.Content.ReadAsStringAsync();
            if (!res.IsSuccessStatusCode)
                throw new Exception($"Access token alınamadı: {json}");

            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.GetProperty("access_token").GetString()
                   ?? throw new Exception("access_token bulunamadı");
        }

        private static string BuildHtml(string code) => $@"
            <div style='font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;background:#f5f5f5;border-radius:12px;'>
              <h2 style='color:#1A237E;'>Hesabınızı Doğrulayın</h2>
              <p>Doğrulama kodunuz:</p>
              <div style='font-size:36px;font-weight:bold;letter-spacing:8px;color:#0D47A1;padding:16px;background:#fff;border-radius:8px;text-align:center;'>{code}</div>
              <p style='color:#666;font-size:12px;margin-top:16px;'>Bu kodu kimseyle paylaşmayın. 15 dakika geçerlidir.</p>
            </div>";
    }
}