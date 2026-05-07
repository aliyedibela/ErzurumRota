namespace TaxiSignalRBackend.WebAPI.Models
{
    public class UserCard
    {
        public string Id { get; set; } = Guid.NewGuid().ToString();
        public string UserId { get; set; } = string.Empty;
        public string CardCode { get; set; } = string.Empty;
        public string CardNickname { get; set; } = "Kartım";
        public decimal Balance { get; set; } = 0;
        public DateTime AddedAt { get; set; } = DateTime.UtcNow;
        public DateTime LastUsedAt { get; set; } = DateTime.UtcNow;

        public User? User { get; set; }
    }
}
