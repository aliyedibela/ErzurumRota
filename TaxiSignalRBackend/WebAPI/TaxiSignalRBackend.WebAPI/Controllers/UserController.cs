using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using TaxiSignalRBackend.WebAPI.Data;
using TaxiSignalRBackend.WebAPI.Models;
using TaxiSignalRBackend.WebAPI.Services;

namespace TaxiSignalRBackend.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UserController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly EmailService _emailService;
        private readonly IConfiguration _config;

        public UserController(AppDbContext db, EmailService emailService, IConfiguration config)
        {
            _db = db;
            _emailService = emailService;
            _config = config;
        }

        [HttpPost("signup")]
        public async Task<IActionResult> Signup([FromBody] UserSignupRequest req)
        {
            try
            {
                Console.WriteLine($"👤 USER SIGNUP: {req.Email}");

                var existing = await _db.Users.FirstOrDefaultAsync(u => u.Email == req.Email);
                if (existing != null)
                    return BadRequest(new { error = "Bu email zaten kayıtlı" });

                var code = new Random().Next(100000, 999999).ToString();

                var user = new User
                {
                    Email = req.Email,
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
                    FullName = req.FullName,
                    PhoneNumber = req.PhoneNumber,
                    VerificationCode = code,
                    IsVerified = false
                };

                _db.Users.Add(user);
                await _db.SaveChangesAsync();

                // Email gönderimini background'da yap — HTTP response beklemeden döner
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await _emailService.SendVerificationEmail(req.Email, code);
                        Console.WriteLine($"✅ Doğrulama emaili gönderildi: {req.Email}");
                    }
                    catch (Exception emailEx)
                    {
                        Console.WriteLine($"⚠️ Email gönderilemedi: {emailEx.Message}");
                    }
                });

                return Ok(new
                {
                    message = "Doğrulama kodu emailinize gönderildi",
                    userId = user.Id,
                    debugCode = code
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 SIGNUP HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }


        [HttpPost("verify")]
        public async Task<IActionResult> Verify([FromBody] UserVerifyRequest req)
        {
            try
            {
                var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == req.UserId);
                if (user == null) return NotFound(new { error = "Kullanıcı bulunamadı" });

                if (user.VerificationCode != req.Code)
                    return BadRequest(new { error = "Yanlış doğrulama kodu" });

                user.IsVerified = true;
                user.VerificationCode = null;
                await _db.SaveChangesAsync();

                Console.WriteLine($"✅ Kullanıcı doğrulandı: {user.Email}");
                return Ok(new { message = "Hesap doğrulandı" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }


        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] UserLoginRequest req)
        {
            try
            {
                Console.WriteLine($"🔑 USER LOGIN: {req.Email}");

                var ip = HttpContext.Request.Headers["X-Forwarded-For"].FirstOrDefault()
                      ?? HttpContext.Connection.RemoteIpAddress?.ToString()
                      ?? "unknown";

                Console.WriteLine($"🌐 Giriş IP: {ip}");

                // Brute force koruması
                var failCount = await _db.LoginLogs.CountAsync(l =>
                    l.IpAddress == ip &&
                    !l.Success &&
                    l.LoginAt > DateTime.UtcNow.AddMinutes(-15));

                if (failCount >= 5)
                {
                    Console.WriteLine($"🚫 Brute force engellendi! IP: {ip}");
                    return StatusCode(429, new { error = "Çok fazla hatalı giriş denemesi. 15 dakika bekleyin." });
                }

                var user = await _db.Users
                    .Include(u => u.Cards)
                    .FirstOrDefaultAsync(u => u.Email == req.Email);

                if (user == null)
                {
                    await _db.LoginLogs.AddAsync(new LoginLog
                    {
                        IpAddress = ip,
                        LoginAt = DateTime.UtcNow,
                        Success = false,
                        FailReason = "Kullanıcı bulunamadı"
                    });
                    await _db.SaveChangesAsync();
                    return Unauthorized(new { error = "Email veya şifre hatalı" });
                }

                if (!BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
                {
                    await _db.LoginLogs.AddAsync(new LoginLog
                    {
                        UserId = user.Id,
                        IpAddress = ip,
                        LoginAt = DateTime.UtcNow,
                        Success = false,
                        FailReason = "Şifre yanlış"
                    });
                    await _db.SaveChangesAsync();
                    return Unauthorized(new { error = "Email veya şifre hatalı" });
                }

                if (!user.IsVerified)
                {
                    await _db.LoginLogs.AddAsync(new LoginLog
                    {
                        UserId = user.Id,
                        IpAddress = ip,
                        LoginAt = DateTime.UtcNow,
                        Success = false,
                        FailReason = "Hesap doğrulanmamış"
                    });
                    await _db.SaveChangesAsync();
                    return BadRequest(new { error = "Lütfen önce emailinizi doğrulayın" });
                }

                var token = GenerateJwtToken(user);

                await _db.LoginLogs.AddAsync(new LoginLog
                {
                    UserId = user.Id,
                    IpAddress = ip,
                    LoginAt = DateTime.UtcNow,
                    Success = true
                });
                await _db.SaveChangesAsync();

                Console.WriteLine($"✅ USER GİRİŞ BAŞARILI: {user.Email}");

                return Ok(new
                {
                    token,
                    id = user.Id,
                    email = user.Email,
                    fullName = user.FullName,
                    phoneNumber = user.PhoneNumber,
                    isVerified = user.IsVerified,
                    cards = user.Cards.Select(c => new {
                        id = c.Id,
                        userId = c.UserId,
                        cardCode = c.CardCode,
                        cardNickname = c.CardNickname,
                        balance = c.Balance,
                        addedAt = c.AddedAt,
                        lastUsedAt = c.LastUsedAt
                    })
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 LOGIN HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("resend-code")]
        public async Task<IActionResult> ResendCode([FromBody] ResendCodeRequest req)
        {
            try
            {
                var user = await _db.Users.FindAsync(req.UserId);
                if (user == null) return NotFound(new { error = "Kullanıcı bulunamadı" });
                if (user.IsVerified) return BadRequest(new { error = "Hesap zaten doğrulanmış" });

                var code = new Random().Next(100000, 999999).ToString();
                user.VerificationCode = code;
                await _db.SaveChangesAsync();

                _ = Task.Run(async () =>
                {
                    try { await _emailService.SendVerificationEmail(user.Email, code); }
                    catch (Exception ex) { Console.WriteLine($"⚠️ Kod tekrar gönderilemedi: {ex.Message}"); }
                });

                return Ok(new { message = "Doğrulama kodu tekrar gönderildi" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest req)
        {
            try
            {
                Console.WriteLine($"🔑 FORGOT PASSWORD: {req.Email}");

                var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == req.Email);
                // Güvenlik: kullanıcı yoksa bile başarılı döndür (email enumeration önleme)
                if (user == null)
                    return Ok(new { message = "Eğer bu email kayıtlıysa sıfırlama kodu gönderildi" });

                var code = new Random().Next(100000, 999999).ToString();
                user.VerificationCode = code;
                await _db.SaveChangesAsync();

                _ = Task.Run(async () =>
                {
                    try { await _emailService.SendPasswordResetEmail(user.Email, code); }
                    catch (Exception ex) { Console.WriteLine($"⚠️ Şifre sıfırlama emaili gönderilemedi: {ex.Message}"); }
                });

                Console.WriteLine($"✅ Şifre sıfırlama kodu gönderildi: {req.Email}");
                return Ok(new { message = "Sıfırlama kodu emailinize gönderildi", debugCode = code });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 FORGOT PASSWORD HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest req)
        {
            try
            {
                Console.WriteLine($"🔑 RESET PASSWORD: {req.Email}");

                var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == req.Email);
                if (user == null) return NotFound(new { error = "Kullanıcı bulunamadı" });

                if (user.VerificationCode != req.Code)
                    return BadRequest(new { error = "Geçersiz veya süresi dolmuş kod" });

                user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.NewPassword);
                user.VerificationCode = null;
                await _db.SaveChangesAsync();

                Console.WriteLine($"✅ Şifre güncellendi: {req.Email}");
                return Ok(new { message = "Şifreniz başarıyla güncellendi" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 RESET PASSWORD HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        // ─── ADMIN: Tüm kullanıcıları listele ───
        // GET /api/user/all?secret=ADMIN_SECRET
        [HttpGet("all")]
        public async Task<IActionResult> GetAllUsers([FromQuery] string secret)
        {
            var adminSecret = _config["Admin:Secret"] ?? "admin123";
            if (secret != adminSecret)
                return Unauthorized(new { error = "Geçersiz admin anahtarı" });

            try
            {
                var users = await _db.Users
                    .Include(u => u.Cards)
                    .OrderByDescending(u => u.CreatedAt)
                    .ToListAsync();

                return Ok(new
                {
                    total = users.Count,
                    verified = users.Count(u => u.IsVerified),
                    unverified = users.Count(u => !u.IsVerified),
                    users = users.Select(u => new
                    {
                        id = u.Id,
                        fullName = u.FullName,
                        email = u.Email,
                        phoneNumber = u.PhoneNumber,
                        isVerified = u.IsVerified,
                        createdAt = u.CreatedAt,
                        cardCount = u.Cards.Count,
                        cards = u.Cards.Select(c => new
                        {
                            cardCode = c.CardCode,
                            cardNickname = c.CardNickname,
                            balance = c.Balance,
                            addedAt = c.AddedAt
                        })
                    })
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 GET ALL USERS HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("{userId}")]
        public async Task<IActionResult> GetProfile(string userId)
        {
            try
            {
                var user = await _db.Users
                    .Include(u => u.Cards)
                    .FirstOrDefaultAsync(u => u.Id == userId);

                if (user == null)
                    return NotFound(new { error = "Kullanıcı bulunamadı" });

                return Ok(new
                {
                    id = user.Id,
                    email = user.Email,
                    fullName = user.FullName,
                    phoneNumber = user.PhoneNumber,
                    isVerified = user.IsVerified,
                    createdAt = user.CreatedAt,
                    cards = user.Cards.Select(c => new {
                        id = c.Id,
                        userId = c.UserId,
                        cardCode = c.CardCode,
                        cardNickname = c.CardNickname,
                        balance = c.Balance,
                        addedAt = c.AddedAt,
                        lastUsedAt = c.LastUsedAt
                    })
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 GET PROFILE HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }


        private string GenerateJwtToken(User user)
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim("userType", "passenger")
            };

            var token = new JwtSecurityToken(
                issuer: _config["Jwt:Issuer"],
                audience: _config["Jwt:Audience"],
                claims: claims,
                expires: DateTime.Now.AddDays(30),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }


    [ApiController]
    [Route("api/[controller]")]
    public class CardController : ControllerBase
    {
        private readonly AppDbContext _db;

        public CardController(AppDbContext db) => _db = db;

        [HttpPost("add")]
        public async Task<IActionResult> AddCard([FromBody] AddCardRequest req)
        {
            try
            {
                var existing = await _db.UserCards.FirstOrDefaultAsync(c => c.CardCode == req.CardCode);
                if (existing != null)
                    return BadRequest(new { error = "Bu kart kodu zaten kayıtlı" });

                var user = await _db.Users.FindAsync(req.UserId);
                if (user == null) return NotFound(new { error = "Kullanıcı bulunamadı" });

                var card = new UserCard
                {
                    UserId = req.UserId,
                    CardCode = req.CardCode,
                    CardNickname = req.CardNickname ?? "Kartım",
                    Balance = 0
                };

                _db.UserCards.Add(card);
                await _db.SaveChangesAsync();

                Console.WriteLine($"💳 Kart eklendi: {req.CardCode} → {user.Email}");

                return Ok(new
                {
                    message = "Kart başarıyla eklendi",
                    card = new
                    {
                        id = card.Id,
                        userId = card.UserId,
                        cardCode = card.CardCode,
                        cardNickname = card.CardNickname,
                        balance = card.Balance,
                        addedAt = card.AddedAt,
                        lastUsedAt = card.LastUsedAt
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 ADD CARD HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpGet("user/{userId}")]
        public async Task<IActionResult> GetCards(string userId)
        {
            try
            {
                var cards = await _db.UserCards
                    .Where(c => c.UserId == userId)
                    .OrderByDescending(c => c.AddedAt)
                    .ToListAsync();

                return Ok(cards.Select(c => new {
                    id = c.Id,
                    userId = c.UserId,
                    cardCode = c.CardCode,
                    cardNickname = c.CardNickname,
                    balance = c.Balance,
                    addedAt = c.AddedAt,
                    lastUsedAt = c.LastUsedAt
                }));
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 GET CARDS HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpDelete("{cardId}")]
        public async Task<IActionResult> DeleteCard(string cardId, [FromQuery] string userId)
        {
            try
            {
                var card = await _db.UserCards.FirstOrDefaultAsync(
                    c => c.Id == cardId && c.UserId == userId);

                if (card == null)
                    return NotFound(new { error = "Kart bulunamadı" });

                _db.UserCards.Remove(card);
                await _db.SaveChangesAsync();

                Console.WriteLine($"🗑️ Kart silindi: {card.CardCode} (User: {userId})");

                return Ok(new { message = "Kart silindi" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 DELETE CARD HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("topup")]
        public async Task<IActionResult> TopUp([FromBody] TopUpRequest req)
        {
            try
            {
                var card = await _db.UserCards.FirstOrDefaultAsync(c => c.CardCode == req.CardCode);
                if (card == null) return NotFound(new { error = "Kart bulunamadı" });

                card.Balance += req.Amount;
                card.LastUsedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();

                Console.WriteLine($"💰 Bakiye yüklendi: {req.CardCode} +{req.Amount}₺ → {card.Balance}₺");

                return Ok(new
                {
                    message = "Bakiye yüklendi",
                    newBalance = card.Balance
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 TOPUP HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }
    }


    public record UserSignupRequest(string Email, string Password, string FullName, string? PhoneNumber);
    public record UserVerifyRequest(string UserId, string Code);
    public record UserLoginRequest(string Email, string Password);
    public record ResendCodeRequest(string UserId);
    public record ForgotPasswordRequest(string Email);
    public record ResetPasswordRequest(string Email, string Code, string NewPassword);
    public record AddCardRequest(string UserId, string CardCode, string? CardNickname);
    public record TopUpRequest(string CardCode, decimal Amount);
}