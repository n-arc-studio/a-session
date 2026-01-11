using System.Net;
using System.Net.Mail;

namespace ASession.Services
{
    public interface IEmailService
    {
        Task SendAsync(string to, string subject, string body);
    }

    public class SmtpEmailService : IEmailService
    {
        private readonly IConfiguration _configuration;
        public SmtpEmailService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task SendAsync(string to, string subject, string body)
        {
            var host = _configuration["Email:Smtp:Host"];
            var portStr = _configuration["Email:Smtp:Port"];
            var username = _configuration["Email:Smtp:Username"];
            var password = _configuration["Email:Smtp:Password"];
            var from = _configuration["Email:From"] ?? username ?? "noreply@example.com";

            if (string.IsNullOrEmpty(host) || string.IsNullOrEmpty(portStr))
            {
                // Fallback: log to console if SMTP is not configured
                Console.WriteLine($"[Email Fallback] To: {to} | Subject: {subject}\n{body}");
                return;
            }

            int port = int.TryParse(portStr, out var p) ? p : 587;
            using var client = new SmtpClient(host, port)
            {
                EnableSsl = true,
                Credentials = string.IsNullOrEmpty(username) ? CredentialCache.DefaultNetworkCredentials : new NetworkCredential(username, password)
            };

            using var message = new MailMessage(from!, to, subject, body)
            {
                IsBodyHtml = false
            };

            await client.SendMailAsync(message);
        }
    }
}
