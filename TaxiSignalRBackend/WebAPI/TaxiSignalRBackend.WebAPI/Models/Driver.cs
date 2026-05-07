using System.ComponentModel.DataAnnotations;

namespace TaxiSignalRBackend.WebAPI.Models
{
    public class Driver
    {
        [Key]
        public string Id { get; set; } = Guid.NewGuid().ToString();
        [Required]
        public string Email { get; set; }
        [Required]
        public string PasswordHash { get; set; }
        [Required]
        public string TaxiStandId { get; set; }
        public string TaxiStandName { get; set; }
        public string DriverName { get; set; }
        public string VehiclePlate { get; set; }
        public string? ConnectionId { get; set; }
        public bool IsOnline { get; set; }
        public bool IsVerified { get; set; }
        public string? VerificationCode { get; set; }
    }
}
