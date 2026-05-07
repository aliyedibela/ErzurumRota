using System.ComponentModel.DataAnnotations;

namespace TaxiSignalRBackend.WebAPI.Models
{
    public class TaxiRequest
    {
        [Key]
        public string RequestId { get; set; } = Guid.NewGuid().ToString();
        public string UserId { get; set; }
        public string TaxiStandId { get; set; }
        public double FromLat { get; set; }
        public double FromLng { get; set; }
        public double ToLat { get; set; }
        public double ToLng { get; set; }
        public double EstimatedFare { get; set; }
        public DateTime RequestTime { get; set; } = DateTime.UtcNow;
        public string Status { get; set; } = "Pending"; 
        public string? DriverId { get; set; }
        public string? DriverName { get; set; }
        public string? DriverPlate { get; set; }

    }
}