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
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly EmailService _emailService;
        private readonly IConfiguration _config;

        public AuthController(AppDbContext db, EmailService emailService, IConfiguration config)
        {
            _db = db;
            _emailService = emailService;
            _config = config;
        }

        [HttpPost("signup")]
        public async Task<IActionResult> Signup([FromBody] SignupRequest req)
        {
            try
            {
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                Console.WriteLine("🚀 SIGNUP İSTEĞİ GELDİ");
                Console.WriteLine($"📧 Email: {req.Email}");
                Console.WriteLine($"🚖 Durak: {req.TaxiStandName} ({req.TaxiStandId})");
                Console.WriteLine($"👤 Sürücü: {req.DriverName}");
                Console.WriteLine($"🚗 Plaka: {req.VehiclePlate}");
                Console.WriteLine($"⏰ Zaman: {DateTime.Now:HH:mm:ss}");
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

                var existingDriver = await _db.Drivers.FirstOrDefaultAsync(d => d.Email == req.Email);
                if (existingDriver != null)
                {
                    Console.WriteLine($"❌ HATA: Bu email zaten kayıtlı! Driver ID: {existingDriver.Id}");
                    return BadRequest(new { error = "Bu email zaten kayıtlı" });
                }
                Console.WriteLine("✅ Email müsait");

                var code = new Random().Next(100000, 999999).ToString();
                Console.WriteLine($"🔐 Doğrulama kodu oluşturuldu: {code}");

                var driver = new Driver
                {
                    Email = req.Email,
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
                    TaxiStandId = req.TaxiStandId,
                    TaxiStandName = req.TaxiStandName,
                    DriverName = req.DriverName,
                    VehiclePlate = req.VehiclePlate,
                    VerificationCode = code,
                    IsVerified = false
                };

                _db.Drivers.Add(driver);
                await _db.SaveChangesAsync();
                Console.WriteLine($"✅ Veritabanına kaydedildi. Driver ID: {driver.Id}");

                // Email gönderimini background'da yap — HTTP response beklemeden döner
                _ = Task.Run(async () =>
                {
                    try
                    {
                        await _emailService.SendVerificationEmail(req.Email, code);
                        Console.WriteLine("✅ Email başarıyla gönderildi!");
                    }
                    catch (Exception emailEx)
                    {
                        Console.WriteLine($"⚠️ EMAIL GÖNDERİMİ BAŞARISIZ: {emailEx.Message}");
                        Console.WriteLine($"⚠️ Debug kodu: {code}");
                    }
                });

                Console.WriteLine("✅ KAYIT BAŞARIYLA TAMAMLANDI!");
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

                return Ok(new
                {
                    message = "Doğrulama kodu emailinize gönderildi",
                    driverId = driver.Id,
                    debugCode = code
                });
            }
            catch (DbUpdateException dbEx)
            {
                Console.WriteLine($"💥 VERİTABANI HATASI: {dbEx.InnerException?.Message ?? dbEx.Message}");
                return StatusCode(500, new { error = $"Veritabanı hatası: {dbEx.InnerException?.Message ?? dbEx.Message}" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 GENEL HATA: {ex.Message}");
                return StatusCode(500, new { error = $"Sunucu hatası: {ex.Message}" });
            }
        }

        [HttpPost("verify")]
        public async Task<IActionResult> Verify([FromBody] VerifyRequest req)
        {
            try
            {
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                Console.WriteLine("🔐 VERIFY İSTEĞİ GELDİ");
                Console.WriteLine($"🆔 Driver ID: {req.DriverId}");
                Console.WriteLine($"🔢 Kod: {req.Code}");
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

                var driver = await _db.Drivers.FirstOrDefaultAsync(d => d.Id == req.DriverId);
                if (driver == null)
                {
                    Console.WriteLine("❌ Sürücü bulunamadı");
                    return NotFound(new { error = "Sürücü bulunamadı" });
                }

                if (driver.VerificationCode != req.Code)
                {
                    Console.WriteLine("❌ Kod eşleşmiyor!");
                    return BadRequest(new { error = "Yanlış kod" });
                }

                driver.IsVerified = true;
                driver.VerificationCode = null;
                await _db.SaveChangesAsync();

                Console.WriteLine("✅ DOĞRULAMA BAŞARILI!");
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

                return Ok(new { message = "Hesap doğrulandı" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 VERIFY HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest req)
        {
            try
            {
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                Console.WriteLine("🔑 LOGIN İSTEĞİ GELDİ");
                Console.WriteLine($"📧 Email: {req.Email}");
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

                // IP al — ngrok/proxy arkasındaysa X-Forwarded-For önce gelir
                var ip = HttpContext.Request.Headers["X-Forwarded-For"].FirstOrDefault()
                      ?? HttpContext.Connection.RemoteIpAddress?.ToString()
                      ?? "unknown";
                Console.WriteLine($"🌐 Giriş IP: {ip}");

                // 🔒 Brute force koruması — 15 dk içinde 5 başarısız deneme
                var failCount = await _db.LoginLogs.CountAsync(l =>
                    l.IpAddress == ip &&
                    !l.Success &&
                    l.LoginAt > DateTime.UtcNow.AddMinutes(-15));

                if (failCount >= 5)
                {
                    Console.WriteLine($"🚫 Brute force engellendi! IP: {ip} ({failCount} başarısız deneme)");
                    return StatusCode(429, new { error = "Çok fazla hatalı giriş denemesi. 15 dakika bekleyin." });
                }

                var driver = await _db.Drivers.FirstOrDefaultAsync(d => d.Email == req.Email);
                if (driver == null)
                {
                    Console.WriteLine("❌ Kullanıcı bulunamadı");
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

                Console.WriteLine($"✅ Kullanıcı bulundu: {driver.DriverName}");

                if (!BCrypt.Net.BCrypt.Verify(req.Password, driver.PasswordHash))
                {
                    Console.WriteLine("❌ Şifre yanlış");
                    await _db.LoginLogs.AddAsync(new LoginLog
                    {
                        DriverId = driver.Id,
                        IpAddress = ip,
                        LoginAt = DateTime.UtcNow,
                        Success = false,
                        FailReason = "Şifre yanlış"
                    });
                    await _db.SaveChangesAsync();
                    return Unauthorized(new { error = "Email veya şifre hatalı" });
                }

                if (!driver.IsVerified)
                {
                    Console.WriteLine("❌ Hesap doğrulanmamış");
                    await _db.LoginLogs.AddAsync(new LoginLog
                    {
                        DriverId = driver.Id,
                        IpAddress = ip,
                        LoginAt = DateTime.UtcNow,
                        Success = false,
                        FailReason = "Hesap doğrulanmamış"
                    });
                    await _db.SaveChangesAsync();
                    return BadRequest(new { error = "Lütfen önce emailinizi doğrulayın" });
                }

                // ✅ Başarılı giriş
                var token = GenerateJwtToken(driver);
                await _db.LoginLogs.AddAsync(new LoginLog
                {
                    DriverId = driver.Id,
                    IpAddress = ip,
                    LoginAt = DateTime.UtcNow,
                    Success = true
                });
                await _db.SaveChangesAsync();

                Console.WriteLine("✅ GİRİŞ BAŞARILI!");
                Console.WriteLine("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

                return Ok(new
                {
                    token,
                    driverId = driver.Id,
                    taxiStandId = driver.TaxiStandId,
                    taxiStandName = driver.TaxiStandName,
                    driverName = driver.DriverName,
                    vehiclePlate = driver.VehiclePlate
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 LOGIN HATASI: {ex.Message}");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        private string GenerateJwtToken(Driver driver)
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, driver.Id),
                new Claim(ClaimTypes.Email, driver.Email)
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

        [HttpGet("test")]
        public IActionResult Test()
        {
            Console.WriteLine("✅ TEST ENDPOINT ÇAĞRILDI");
            return Ok(new
            {
                message = "AuthController çalışıyor!",
                timestamp = DateTime.Now,
                environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
                database = _db.Database.CanConnect() ? "Bağlantı OK" : "Bağlantı HATASI"
            });
        }
    }

    public record SignupRequest(string Email, string Password, string TaxiStandId, string TaxiStandName, string DriverName, string VehiclePlate);
    public record VerifyRequest(string DriverId, string Code);
    public record LoginRequest(string Email, string Password);
}