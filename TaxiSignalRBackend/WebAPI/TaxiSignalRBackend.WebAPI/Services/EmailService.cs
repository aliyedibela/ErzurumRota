using System.Net.Mail;

namespace TaxiSignalRBackend.WebAPI.Services
{
    public class EmailService
    {
        private const string GmailUser = "erzurumbbappetu@gmail.com";
        private const string GmailAppPassword = "xtav lvcq srlj bfik"; // Google Uygulama Şifresi

        public async Task SendVerificationEmail(string toEmail, string code)
        {
            using var client = new SmtpClient("smtp.gmail.com", 587)
            {
                Credentials = new System.Net.NetworkCredential(GmailUser, GmailAppPassword),
                EnableSsl = true,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                Timeout = 15000
            };

            var mail = new MailMessage
            {
                From = new MailAddress(GmailUser, "Erzurum BB App"),
                Subject = "Doğrulama Kodunuz",
                Body = BuildHtml(code),
                IsBodyHtml = true
            };
            mail.To.Add(toEmail);

            await client.SendMailAsync(mail);
            Console.WriteLine($"✅ Gmail SMTP ile email gönderildi: {toEmail}");
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
