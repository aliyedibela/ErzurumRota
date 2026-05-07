using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using TaxiSignalRBackend.WebAPI.Data;
using TaxiSignalRBackend.WebAPI.Models;

namespace TaxiSignalRBackend.WebAPI.Hubs
{
    public class TaxiHub : Hub
    {
        private readonly AppDbContext _db;
        private static Dictionary<string, string> _driverConnections = new(); 

        public TaxiHub(AppDbContext db)
        {
            _db = db;
        }

        public async Task RegisterDriver(string driverId)
        {
            var driver = await _db.Drivers.FindAsync(driverId);
            if (driver != null)
            {
                driver.ConnectionId = Context.ConnectionId;
                driver.IsOnline = true;
                _driverConnections[driverId] = Context.ConnectionId;
                await _db.SaveChangesAsync();

                await Clients.Caller.SendAsync("DriverRegistered", new { message = "Online olarak kayıt edildiniz", driverName = driver.DriverName });
            }
        }

        public async Task RequestTaxi(TaxiRequest request)
        {
            _db.TaxiRequests.Add(request);
            await _db.SaveChangesAsync();

            var driversAtStand = await _db.Drivers
                .Where(d => d.TaxiStandId == request.TaxiStandId && d.IsOnline && d.ConnectionId != null)
                .ToListAsync();

            foreach (var driver in driversAtStand)
            {
                await Clients.Client(driver.ConnectionId).SendAsync("NewTaxiRequest", request);
            }
        }

        public async Task AcceptRequest(string requestId, string driverId)
        {
            var request = await _db.TaxiRequests.FindAsync(requestId);
            var driver = await _db.Drivers.FindAsync(driverId);

            if (request != null && driver != null)
            {
                request.Status = "Accepted";
                request.DriverId = driverId;
                request.DriverName = driver.DriverName;
                request.DriverPlate = driver.VehiclePlate;
                await _db.SaveChangesAsync();
                await Clients.All.SendAsync("TaxiAccepted", new
                {
                    requestId,
                    driverName = driver.DriverName,
                    plate = driver.VehiclePlate,
                    message = "Sürücü yola çıktı!"
                });

                var otherDrivers = await _db.Drivers
                    .Where(d => d.TaxiStandId == request.TaxiStandId && d.Id != driverId && d.IsOnline)
                    .ToListAsync();

                foreach (var otherDriver in otherDrivers)
                {
                    if (!string.IsNullOrEmpty(otherDriver.ConnectionId))
                        await Clients.Client(otherDriver.ConnectionId).SendAsync("RequestClosed", requestId);
                }
            }
        }

        public async Task RejectRequest(string requestId, string driverId)
        {
            var request = await _db.TaxiRequests.FindAsync(requestId);
            if (request != null)
            {
                request.Status = "Rejected";
                await _db.SaveChangesAsync();
            }
            await Clients.All.SendAsync("TaxiRejected", new { requestId });
        }
        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var driver = await _db.Drivers.FirstOrDefaultAsync(d => d.ConnectionId == Context.ConnectionId);
            if (driver != null)
            {
                driver.IsOnline = false;
                driver.ConnectionId = null;
                _driverConnections.Remove(driver.Id);
                await _db.SaveChangesAsync();
            }
            await base.OnDisconnectedAsync(exception);
        }
    }
}