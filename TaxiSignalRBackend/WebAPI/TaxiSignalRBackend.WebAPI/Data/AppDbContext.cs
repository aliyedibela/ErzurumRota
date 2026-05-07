using Microsoft.EntityFrameworkCore;
using TaxiSignalRBackend.WebAPI.Models;

namespace TaxiSignalRBackend.WebAPI.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<Driver> Drivers { get; set; }
        public DbSet<TaxiRequest> TaxiRequests { get; set; }

        public DbSet<User> Users { get; set; }
        public DbSet<UserCard> UserCards { get; set; }

        public DbSet<LoginLog> LoginLogs { get; set; }
        public DbSet<PaymentTransaction> PaymentTransactions { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Driver>()
                .HasIndex(d => d.Email)
                .IsUnique();

            modelBuilder.Entity<User>(e =>
            {
                e.HasKey(u => u.Id);
                e.HasIndex(u => u.Email).IsUnique();
                e.Property(u => u.Email).IsRequired().HasMaxLength(200);
                e.Property(u => u.PasswordHash).IsRequired();
                e.Property(u => u.FullName).IsRequired().HasMaxLength(100);
            });

            modelBuilder.Entity<PaymentTransaction>(e =>
            {
                e.HasKey(t => t.Id);

                e.Property(t => t.Amount).HasColumnType("decimal(10,2)");
                e.Property(t => t.OldBalance).HasColumnType("decimal(10,2)");
                e.Property(t => t.NewBalance).HasColumnType("decimal(10,2)");


                e.HasOne(t => t.Card)
                 .WithMany() 
                 .HasForeignKey(t => t.CardId)
                 .OnDelete(DeleteBehavior.Restrict); 

                e.HasOne(t => t.User)
                 .WithMany()  
                 .HasForeignKey(t => t.UserId)
                 .OnDelete(DeleteBehavior.Restrict); 
            });

            modelBuilder.Entity<UserCard>(e =>
            {
                e.HasKey(c => c.Id);
                e.HasIndex(c => c.CardCode).IsUnique();
                e.Property(c => c.CardCode).IsRequired().HasMaxLength(50);
                e.Property(c => c.Balance).HasColumnType("decimal(10,2)");
                e.HasOne(c => c.User)
                 .WithMany(u => u.Cards)
                 .HasForeignKey(c => c.UserId)
                 .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}