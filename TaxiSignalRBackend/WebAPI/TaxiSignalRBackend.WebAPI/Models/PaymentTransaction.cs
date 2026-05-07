using System.ComponentModel.DataAnnotations;

namespace TaxiSignalRBackend.WebAPI.Models
{

    public class PaymentTransaction
    {
        [Key]
        public string Id { get; set; } = Guid.NewGuid().ToString();

        public string CardId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;

        public decimal Amount { get; set; }
        public string Description { get; set; } = "RFID Ödeme";

        public decimal OldBalance { get; set; }
        public decimal NewBalance { get; set; }

        public string? DeviceId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public UserCard? Card { get; set; }
        public User? User { get; set; }
    }
}
