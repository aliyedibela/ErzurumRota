using Iyzipay;
using Iyzipay.Model;
using Iyzipay.Request;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using TaxiSignalRBackend.WebAPI.Data;
using TaxiSignalRBackend.WebAPI.Models;

namespace TaxiSignalRBackend.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PaymentController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly IyzicoSettings _iyzicoSettings;

        public PaymentController(AppDbContext db, IOptions<IyzicoSettings> iyzicoSettings)
        {
            _db = db;
            _iyzicoSettings = iyzicoSettings.Value;
        }

        [HttpPost("process")]
        public async Task<IActionResult> ProcessPayment([FromBody] ProcessPaymentRequest req)
        {
            try
            {
                Console.WriteLine($"💰 ÖDEME İŞLEMİ: {req.CardCode} → {req.Amount}₺");

                var card = await _db.UserCards
                    .Include(c => c.User)
                    .FirstOrDefaultAsync(c => c.CardCode.ToUpper() == req.CardCode.ToUpper());

                if (card == null)
                {
                    Console.WriteLine($"❌ Kart bulunamadı: {req.CardCode}");
                    return NotFound(new { success = false, error = "Kart sisteme kayıtlı değil" });
                }

                if (card.Balance < req.Amount)
                {
                    Console.WriteLine($"⚠️ Yetersiz bakiye: {card.Balance}₺ < {req.Amount}₺");
                    return Ok(new
                    {
                        success = false,
                        error = "Yetersiz bakiye",
                        cardNickname = card.CardNickname,
                        userName = card.User?.FullName ?? "Kullanıcı",
                        currentBalance = card.Balance,
                        requiredAmount = req.Amount,
                        shortage = req.Amount - card.Balance
                    });
                }

                var oldBalance = card.Balance;
                card.Balance -= req.Amount;
                card.LastUsedAt = DateTime.UtcNow;

                var transaction = new PaymentTransaction
                {
                    CardId = card.Id,
                    UserId = card.UserId,
                    Amount = -req.Amount,
                    Description = req.Description ?? "RFID Ödeme",
                    DeviceId = req.DeviceId,
                    OldBalance = oldBalance,
                    NewBalance = card.Balance
                };

                _db.PaymentTransactions.Add(transaction);
                await _db.SaveChangesAsync();

                Console.WriteLine($"✅ ÖDEME BAŞARILI: {card.CardNickname}");
                Console.WriteLine($"   {card.User?.FullName ?? "Kullanıcı"}");
                Console.WriteLine($"   Önceki: {oldBalance}₺ → Yeni: {card.Balance}₺");

                return Ok(new
                {
                    success = true,
                    message = "Ödeme başarılı",
                    transactionId = transaction.Id,
                    cardNickname = card.CardNickname,
                    userName = card.User?.FullName ?? "Kullanıcı",
                    amount = -req.Amount,
                    oldBalance = oldBalance,
                    newBalance = card.Balance,
                    timestamp = transaction.CreatedAt
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 PROCESS PAYMENT HATASI: {ex.Message}");
                return StatusCode(500, new { success = false, error = ex.Message });
            }
        }

        [HttpGet("balance/{cardCode}")]
        public async Task<IActionResult> GetBalance(string cardCode)
        {
            try
            {
                var card = await _db.UserCards
                    .Include(c => c.User)
                    .FirstOrDefaultAsync(c => c.CardCode.ToUpper() == cardCode.ToUpper());

                if (card == null)
                    return NotFound(new { success = false, error = "Kart bulunamadı" });

                return Ok(new
                {
                    success = true,
                    cardNickname = card.CardNickname,
                    userName = card.User?.FullName ?? "Kullanıcı",
                    balance = card.Balance,
                    lastUsed = card.LastUsedAt
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 GET BALANCE HATASI: {ex.Message}");
                return StatusCode(500, new { success = false, error = ex.Message });
            }
        }

        [HttpPost("iyzico")]
        public async Task<IActionResult> ProcessIyzicoPayment([FromBody] IyzicoPaymentRequest req)
        {
            try
            {
                Console.WriteLine($"🔵 Iyzico ödeme başlatılıyor: {req.Amount}₺");

                var options = new Iyzipay.Options
                {
                    ApiKey = _iyzicoSettings.ApiKey,
                    SecretKey = _iyzicoSettings.SecretKey,
                    BaseUrl = _iyzicoSettings.BaseUrl
                };

                var randomString = DateTime.Now.Ticks.ToString();

                var paymentRequest = new CreatePaymentRequest
                {
                    Locale = Locale.TR.ToString(),
                    ConversationId = randomString,
                    Price = req.Amount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
                    PaidPrice = req.Amount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
                    Currency = Currency.TRY.ToString(),
                    Installment = 1,
                    BasketId = $"B{randomString}",
                    PaymentChannel = PaymentChannel.WEB.ToString(),
                    PaymentGroup = PaymentGroup.PRODUCT.ToString(),

                    PaymentCard = new PaymentCard
                    {
                        CardHolderName = req.CardDetails.CardHolder,
                        CardNumber = req.CardDetails.CardNumber.Replace(" ", ""),
                        ExpireMonth = req.CardDetails.ExpMonth.PadLeft(2, '0'),
                        ExpireYear = req.CardDetails.ExpYear.Length == 2 ? $"20{req.CardDetails.ExpYear}" : req.CardDetails.ExpYear,
                        Cvc = req.CardDetails.Cvv,
                        RegisterCard = 0
                    },

                    Buyer = new Buyer
                    {
                        Id = $"BY{randomString}",
                        Name = req.UserName.Split(' ').FirstOrDefault() ?? "User",
                        Surname = req.UserName.Split(' ').Skip(1).FirstOrDefault() ?? "User",
                        GsmNumber = "+905555555555",
                        Email = req.UserEmail,
                        IdentityNumber = "11111111111",
                        RegistrationAddress = "Erzurum, Turkiye",
                        Ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "85.34.78.112",
                        City = "Erzurum",
                        Country = "Turkey",
                        ZipCode = "25000"
                    },

                    ShippingAddress = new Address
                    {
                        ContactName = req.UserName,
                        City = "Erzurum",
                        Country = "Turkey",
                        Description = "Erzurum, Turkiye",
                        ZipCode = "25000"
                    },

                    BillingAddress = new Address
                    {
                        ContactName = req.UserName,
                        City = "Erzurum",
                        Country = "Turkey",
                        Description = "Erzurum, Turkiye",
                        ZipCode = "25000"
                    },

                    BasketItems = new List<BasketItem>
            {
                new BasketItem
                {
                    Id = $"BI{randomString}",
                    Name = "RFID Kart Yukleme",
                    Category1 = "Ulasim",
                    Category2 = "Kart",
                    ItemType = BasketItemType.VIRTUAL.ToString(),
                    Price = req.Amount.ToString("F2", System.Globalization.CultureInfo.InvariantCulture)
                }
            }
                };

                var payment = await Task.Run(() => Payment.Create(paymentRequest, options));

                Console.WriteLine($"🔵 Iyzico yanıt: {payment.Status}");
                Console.WriteLine($"🔵 Iyzico tam yanıt: {payment.ErrorMessage ?? "OK"}");

                if (payment.Status == "success")
                {
                    var card = await _db.UserCards
                        .Include(c => c.User)
                        .FirstOrDefaultAsync(c => c.CardCode.ToUpper() == req.CardCode.ToUpper());

                    if (card == null)
                    {
                        Console.WriteLine($"❌ Kart bulunamadı: {req.CardCode}");
                        return NotFound(new { success = false, error = "Kart bulunamadı" });
                    }

                    var oldBalance = card.Balance;
                    card.Balance += req.Amount;
                    card.LastUsedAt = DateTime.UtcNow;

                    var transaction = new PaymentTransaction
                    {
                        CardId = card.Id,
                        UserId = card.UserId,
                        Amount = req.Amount,
                        Description = $"Iyzico Ödeme (ID: {payment.PaymentId})",
                        DeviceId = "IYZICO",
                        OldBalance = oldBalance,
                        NewBalance = card.Balance
                    };

                    _db.PaymentTransactions.Add(transaction);
                    await _db.SaveChangesAsync();

                    Console.WriteLine($"✅ Bakiye yüklendi: {card.CardNickname}");
                    Console.WriteLine($"   +{req.Amount}₺ → {card.Balance}₺");

                    return Ok(new
                    {
                        success = true,
                        paymentId = payment.PaymentId,
                        amount = req.Amount,
                        oldBalance = oldBalance,
                        newBalance = card.Balance,
                        cardNickname = card.CardNickname
                    });
                }
                else
                {
                    Console.WriteLine($"❌ Iyzico hatası: {payment.ErrorMessage}");
                    return BadRequest(new
                    {
                        success = false,
                        error = payment.ErrorMessage
                            ?? payment.ErrorCode
                            ?? "Ödeme başarısız"
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 IYZICO HATASI: {ex.Message}");
                Console.WriteLine($"Stack: {ex.StackTrace}");
                return StatusCode(500, new { success = false, error = ex.Message });
            }
        }

        [HttpGet("history/{cardCode}")]
        public async Task<IActionResult> GetHistory(string cardCode, [FromQuery] int limit = 10)
        {
            try
            {
                var card = await _db.UserCards
                    .FirstOrDefaultAsync(c => c.CardCode.ToUpper() == cardCode.ToUpper());

                if (card == null)
                    return NotFound(new { success = false, error = "Kart bulunamadı" });

                var transactions = await _db.PaymentTransactions
                    .Where(t => t.CardId == card.Id)
                    .OrderByDescending(t => t.CreatedAt)
                    .Take(limit)
                    .Select(t => new
                    {
                        t.Id,
                        t.Amount,
                        t.Description,
                        t.OldBalance,
                        t.NewBalance,
                        t.CreatedAt,
                        t.DeviceId
                    })
                    .ToListAsync();

                return Ok(new
                {
                    success = true,
                    cardNickname = card.CardNickname,
                    currentBalance = card.Balance,
                    transactionCount = transactions.Count,
                    transactions
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 GET HISTORY HATASI: {ex.Message}");
                return StatusCode(500, new { success = false, error = ex.Message });
            }
        }

        [HttpPost("topup")]
        public async Task<IActionResult> TopUp([FromBody] TopUpRequest req)
        {
            try
            {
                var card = await _db.UserCards
                    .Include(c => c.User)
                    .FirstOrDefaultAsync(c => c.CardCode.ToUpper() == req.CardCode.ToUpper());

                if (card == null)
                    return NotFound(new { success = false, error = "Kart bulunamadı" });

                var oldBalance = card.Balance;
                card.Balance += req.Amount;
                card.LastUsedAt = DateTime.UtcNow;

                var transaction = new PaymentTransaction
                {
                    CardId = card.Id,
                    UserId = card.UserId,
                    Amount = req.Amount,
                    Description = "Bakiye Yükleme",
                    DeviceId = "MANUAL",
                    OldBalance = oldBalance,
                    NewBalance = card.Balance
                };

                _db.PaymentTransactions.Add(transaction);
                await _db.SaveChangesAsync();

                Console.WriteLine($"💰 BAKİYE YÜKLENDİ: {card.CardNickname}");
                Console.WriteLine($"   +{req.Amount}₺ → {card.Balance}₺");

                return Ok(new
                {
                    success = true,
                    message = "Bakiye yüklendi",
                    transactionId = transaction.Id,
                    cardNickname = card.CardNickname,
                    userName = card.User?.FullName ?? "Kullanıcı",
                    amount = req.Amount,
                    oldBalance = oldBalance,
                    newBalance = card.Balance
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"💥 TOPUP HATASI: {ex.Message}");
                return StatusCode(500, new { success = false, error = ex.Message });
            }
        }
    }

    public record ProcessPaymentRequest(
        string CardCode,
        decimal Amount,
        string? Description,
        string? DeviceId
    );

    public record IyzicoPaymentRequest(
        string CardCode,
        decimal Amount,
        string UserEmail,
        string UserName,
        CardDetailsDto CardDetails
    );

    public record CardDetailsDto(
        string CardNumber,
        string CardHolder,
        string ExpMonth,
        string ExpYear,
        string Cvv
    );
}