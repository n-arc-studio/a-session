using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using ASession.Data;
using ASession.Services;
using Npgsql;

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
}

static async Task EnsureDatabaseExistsAsync(string connectionString)
{
    var builder = new NpgsqlConnectionStringBuilder(connectionString)
    {
        Encoding = "UTF8"
    };
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
        command.CommandText = $"CREATE DATABASE \"{databaseName}\" ENCODING 'UTF8'";
        await command.ExecuteNonQueryAsync();
    }
}

app.Run();


