using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;

using TaxiSignalRBackend.WebAPI.Data;
using TaxiSignalRBackend.WebAPI.Hubs;
using TaxiSignalRBackend.WebAPI.Models;
using TaxiSignalRBackend.WebAPI.Services;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
{
    var port = int.Parse(Environment.GetEnvironmentVariable("PORT") ?? "5091");
    options.ListenAnyIP(port);
});

builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.Configure<IyzicoSettings>(builder.Configuration.GetSection("Iyzico"));

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]))
        };
    });

builder.Services.AddSignalR();
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
        options.JsonSerializerOptions.PropertyNamingPolicy = null; 
        options.JsonSerializerOptions.WriteIndented = true;
    });

builder.Services.AddSingleton<EmailService>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "TaxiSignalRBackend API", Version = "v1" });
});

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.Migrate();
        Console.WriteLine("✅ Veritabanı migration tamamlandı");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"⚠️ Migration başarısız, EnsureCreated deneniyor: {ex.Message}");
        db.Database.EnsureCreated();
        Console.WriteLine("✅ Veritabanı EnsureCreated ile hazır");
    }
}

// ─── Health check endpoint (Railway.app ping için) ───
app.MapGet("/health", () => Results.Ok(new { status = "ok", timestamp = DateTime.UtcNow }));

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "TaxiSignalRBackend API V1");
    c.RoutePrefix = string.Empty;
});

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

app.Use(async (context, next) =>
{
    Console.WriteLine($"📥 {context.Request.Method} {context.Request.Path} - {DateTime.Now:HH:mm:ss}");
    await next();
    Console.WriteLine($"📤 Response: {context.Response.StatusCode}");
});


app.MapHub<TaxiHub>("/taxiHub");
app.MapControllers();

Console.WriteLine("🚀 Sunucu başlatılıyor...");
Console.WriteLine("📍 HTTP: http://localhost:5091");
Console.WriteLine("📍 Swagger: http://localhost:5091");
Console.WriteLine("📍 Auth Test: http://localhost:5091/api/auth/test");

app.Run();