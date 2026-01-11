using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using ASession.Data;
using ASession.Services;
using Npgsql;
using ASession.Models;
using Microsoft.AspNetCore.Identity;
using static BCrypt.Net.BCrypt;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Entity Framework
builder.Services.AddDbContext<ASessionDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Add JWT Service
builder.Services.AddScoped<JwtService>();
builder.Services.AddScoped<IEmailService, SmtpEmailService>();

// Add Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"] ?? "default-secret-key"))
        };
    });

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

// Apply database migrations
using (var scope = app.Services.CreateScope())
{
    var dbContext = scope.ServiceProvider.GetRequiredService<ASessionDbContext>();
    
    // Create database if it doesn't exist
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    if (connectionString != null)
    {
        await EnsureDatabaseExistsAsync(connectionString);
    }
    
    // Apply migrations
    await dbContext.Database.MigrateAsync();
    
    // Create admin user if not exists
    await CreateAdminUserIfNotExistsAsync(dbContext, builder.Configuration);
}

static async Task EnsureDatabaseExistsAsync(string connectionString)
{
    var builder = new NpgsqlConnectionStringBuilder(connectionString);
    var databaseName = builder.Database;
    builder.Database = "postgres"; // Connect to default database
    
    using var connection = new NpgsqlConnection(builder.ToString());
    await connection.OpenAsync();
    
    using var command = connection.CreateCommand();
    command.CommandText = $"SELECT 1 FROM pg_database WHERE datname = '{databaseName}'";
    
    var result = await command.ExecuteScalarAsync();
    if (result == null)
    {
        // Database doesn't exist, create it
        command.CommandText = $"CREATE DATABASE \"{databaseName}\"";
        await command.ExecuteNonQueryAsync();
    }
}

app.Run();

async Task CreateAdminUserIfNotExistsAsync(ASessionDbContext dbContext, IConfiguration configuration)
{
    var adminEmail = configuration["AdminUser:Email"];
    var adminPassword = configuration["AdminUser:Password"];

    if (string.IsNullOrEmpty(adminEmail) || string.IsNullOrEmpty(adminPassword))
    {
        throw new InvalidOperationException("Admin user email or password is not configured.");
    }

    // Check if the admin user already exists
    var adminUser = await dbContext.Users
        .FirstOrDefaultAsync(u => u.Email == adminEmail);
    if (adminUser == null)
    {
        var hashedPassword = HashPassword(adminPassword);
        
        adminUser = new User
        {
            Email = adminEmail,
            PasswordHash = hashedPassword,
            IsAdmin = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        dbContext.Users.Add(adminUser);
        await dbContext.SaveChangesAsync();
        Console.WriteLine("Admin user created successfully.");
    }
    else
    {
        Console.WriteLine("Admin user already exists.");
    }
}


