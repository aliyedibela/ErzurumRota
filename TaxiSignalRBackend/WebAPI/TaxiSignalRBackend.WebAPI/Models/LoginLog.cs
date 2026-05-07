namespace TaxiSignalRBackend.WebAPI.Models
{
    public class LoginLog
    {
        public int Id { get; set; }
        public string? DriverId { get; set; }
        public string IpAddress { get; set; } = "unknown";
        public DateTime LoginAt { get; set; }

        public string? UserId { get; set; }
        public bool Success { get; set; }
        public string? FailReason { get; set; }
    }
}