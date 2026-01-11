using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using ASession.Data;
using ASession.Models;
using ASession.Services;
using static BCrypt.Net.BCrypt;

namespace ASession.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UsersController : ControllerBase
    {
        private readonly ASessionDbContext _context;
        private readonly JwtService _jwtService;
        private readonly IConfiguration _configuration;
        private readonly IEmailService _emailService;

        public UsersController(ASessionDbContext context, JwtService jwtService, IConfiguration configuration, IEmailService emailService)
        {
            _context = context;
            _jwtService = jwtService;
            _configuration = configuration;
            _emailService = emailService;
        }

        // GET: api/Users
        [HttpGet]
        public async Task<ActionResult<IEnumerable<User>>> GetUsers()
        {
            return await _context.Users.ToListAsync();
        }

        // GET: api/Users/5
        [HttpGet("{id}")]
        public async Task<ActionResult<User>> GetUser(int id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
            {
                return NotFound();
            }
            return user;
        }

        // PUT: api/Users/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutUser(int id, User user)
        {
            if (id != user.Id)
            {
                return BadRequest();
            }

            user.UpdatedAt = DateTime.UtcNow;
            _context.Entry(user).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!UserExists(id))
                {
                    return NotFound();
                }
                throw;
            }

            return NoContent();
        }

        // POST: api/Users
        [HttpPost]
        public async Task<ActionResult<User>> PostUser(User user)
        {
            user.CreatedAt = DateTime.UtcNow;
            user.UpdatedAt = DateTime.UtcNow;
            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetUser", new { id = user.Id }, user);
        }

        // DELETE: api/Users/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null)
            {
                return NotFound();
            }

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool UserExists(int id)
        {
            return _context.Users.Any(e => e.Id == id);
        }

        // POST: api/Users/register
        [HttpPost("register")]
        public async Task<ActionResult<User>> Register([FromBody] RegisterRequest request)
        {
            if (await _context.Users.AnyAsync(u => u.Email == request.Email))
            {
                return BadRequest("Email already exists");
            }

            var user = new User
            {
                Name = request.Name,
                Email = request.Email,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            user.PasswordHash = HashPassword(request.Password);

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            await CreateAndSendOtpAsync(user, "verify");
            return CreatedAtAction("GetUser", new { id = user.Id }, user);
        }

        // POST: api/Users/login
        [HttpPost("login")]
        public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
            {
                return Unauthorized("Invalid email or password");
            }

            var result = Verify(request.Password, user.PasswordHash);
            if (!result)
            {
                return Unauthorized("Invalid email or password");
            }

            var token = _jwtService.GenerateToken(user);
            return new LoginResponse { Token = token, User = user };
        }

        // POST: api/Users/login/google
        [HttpPost("login/google")]
        public async Task<ActionResult<LoginResponse>> GoogleLogin([FromBody] OAuthLoginRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.IdToken))
            {
                return BadRequest("Missing idToken");
            }

            try
            {
                var clientId = _configuration["OAuth:Google:ClientId"];
                var payload = await Google.Apis.Auth.GoogleJsonWebSignature.ValidateAsync(
                    request.IdToken,
                    new Google.Apis.Auth.GoogleJsonWebSignature.ValidationSettings
                    {
                        Audience = string.IsNullOrEmpty(clientId) ? null : new[] { clientId }
                    }
                );

                var email = payload.Email;
                var name = payload.Name ?? payload.Email;
                var googleUserId = payload.Subject;

                var user = await _context.Users.FirstOrDefaultAsync(u => u.GoogleId == googleUserId || u.Email == email);
                if (user == null)
                {
                    user = new User
                    {
                        Name = name,
                        Email = email,
                        GoogleId = googleUserId,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow,
                        PasswordHash = HashPassword(Guid.NewGuid().ToString()),
                        IsEmailVerified = true
                    };
                    _context.Users.Add(user);
                }
                else
                {
                    if (string.IsNullOrEmpty(user.GoogleId))
                    {
                        user.GoogleId = googleUserId;
                    }
                    user.UpdatedAt = DateTime.UtcNow;
                }

                await _context.SaveChangesAsync();
                var token = _jwtService.GenerateToken(user);
                return new LoginResponse { Token = token, User = user };
            }
            catch (Exception ex)
            {
                return Unauthorized($"Google token validation failed: {ex.Message}");
            }
        }

        // POST: api/Users/login/apple
        [HttpPost("login/apple")]
        public async Task<ActionResult<LoginResponse>> AppleLogin([FromBody] OAuthLoginRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.IdToken))
            {
                return BadRequest("Missing idToken");
            }

            var clientId = _configuration["OAuth:Apple:ClientId"];
            if (string.IsNullOrEmpty(clientId))
            {
                return BadRequest("Apple ClientId is not configured");
            }

            try
            {
                var tokenHandler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
                var keys = await GetAppleSigningKeysAsync();

                var validationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = "https://appleid.apple.com",
                    ValidateAudience = true,
                    ValidAudience = clientId,
                    ValidateLifetime = true,
                    RequireSignedTokens = true,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKeys = keys
                };

                var principal = tokenHandler.ValidateToken(request.IdToken, validationParameters, out var securityToken);
                var jwtToken = securityToken as System.IdentityModel.Tokens.Jwt.JwtSecurityToken;
                if (jwtToken == null)
                {
                    return Unauthorized("Invalid Apple token");
                }

                var email = principal.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Email) ?? principal.FindFirstValue(ClaimTypes.Email) ?? string.Empty;
                var name = principal.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Name) ?? email;
                var appleUserId = principal.FindFirstValue(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub) ?? string.Empty;

                if (string.IsNullOrEmpty(appleUserId))
                {
                    return Unauthorized("Apple token missing subject");
                }

                var user = await _context.Users.FirstOrDefaultAsync(u => u.AppleId == appleUserId || (!string.IsNullOrEmpty(email) && u.Email == email));
                if (user == null)
                {
                    user = new User
                    {
                        Name = name,
                        Email = string.IsNullOrEmpty(email) ? $"apple_{appleUserId}@example.com" : email,
                        AppleId = appleUserId,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow,
                        PasswordHash = HashPassword(Guid.NewGuid().ToString()),
                        IsEmailVerified = true
                    };
                    _context.Users.Add(user);
                }
                else
                {
                    if (string.IsNullOrEmpty(user.AppleId))
                    {
                        user.AppleId = appleUserId;
                    }
                    user.UpdatedAt = DateTime.UtcNow;
                }

                await _context.SaveChangesAsync();
                var token = _jwtService.GenerateToken(user);
                return new LoginResponse { Token = token, User = user };
            }
            catch (Exception ex)
            {
                return Unauthorized($"Apple token validation failed: {ex.Message}");
            }
        }

        private static IList<Microsoft.IdentityModel.Tokens.SecurityKey>? _appleSigningKeys;
        private static DateTime _appleKeysFetchedAt;
        private static readonly TimeSpan _appleKeysCacheTtl = TimeSpan.FromHours(1);

        private static async Task<IList<Microsoft.IdentityModel.Tokens.SecurityKey>> GetAppleSigningKeysAsync()
        {
            if (_appleSigningKeys != null && (DateTime.UtcNow - _appleKeysFetchedAt) < _appleKeysCacheTtl)
            {
                return _appleSigningKeys;
            }

            using var httpClient = new HttpClient();
            var jwksJson = await httpClient.GetStringAsync("https://appleid.apple.com/auth/keys");
            var jwks = new Microsoft.IdentityModel.Tokens.JsonWebKeySet(jwksJson);
            _appleSigningKeys = jwks.GetSigningKeys();
            _appleKeysFetchedAt = DateTime.UtcNow;
            return _appleSigningKeys;
        }

        // POST: api/Users/logout
        [HttpPost("logout")]
        [Authorize]
        public IActionResult Logout()
        {
            return Ok(new { message = "Logged out successfully" });
        }

        // DELETE: api/Users/delete-account
        [HttpDelete("delete-account")]
        [Authorize]
        public async Task<IActionResult> DeleteAccount()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out var userId))
            {
                return Unauthorized();
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                return NotFound();
            }

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Account deleted successfully" });
        }

        // POST: api/Users/send-otp
        [HttpPost("send-otp")]
        public async Task<IActionResult> SendOtp([FromBody] SendOtpRequest request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
            {
                return NotFound("User not found");
            }

            await CreateAndSendOtpAsync(user, request.Purpose ?? "verify");
            return Ok(new { message = "OTP sent" });
        }

        // POST: api/Users/verify-email
        [HttpPost("verify-email")]
        public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequest request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
            {
                return NotFound("User not found");
            }

            var now = DateTime.UtcNow;
            var otp = await _context.OtpCodes.FirstOrDefaultAsync(o => o.UserId == user.Id && o.Purpose == "verify" && o.Code == request.Code && !o.IsUsed && o.ExpiresAt > now);
            if (otp == null)
            {
                return BadRequest("Invalid or expired code");
            }

            otp.IsUsed = true;
            user.IsEmailVerified = true;
            user.UpdatedAt = now;
            await _context.SaveChangesAsync();
            return Ok(new { message = "Email verified" });
        }

        // POST: api/Users/request-password-reset
        [HttpPost("request-password-reset")]
        public async Task<IActionResult> RequestPasswordReset([FromBody] PasswordResetRequest request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
            {
                return Ok(new { message = "If the email exists, a code was sent" });
            }

            await CreateAndSendOtpAsync(user, "reset");
            return Ok(new { message = "If the email exists, a code was sent" });
        }

        // POST: api/Users/reset-password
        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] PerformPasswordResetRequest request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
            {
                return BadRequest("Invalid request");
            }

            var now = DateTime.UtcNow;
            var otp = await _context.OtpCodes.FirstOrDefaultAsync(o => o.UserId == user.Id && o.Purpose == "reset" && o.Code == request.Code && !o.IsUsed && o.ExpiresAt > now);
            if (otp == null)
            {
                return BadRequest("Invalid or expired code");
            }

            user.PasswordHash = HashPassword(request.NewPassword);
            user.UpdatedAt = now;
            otp.IsUsed = true;
            await _context.SaveChangesAsync();
            return Ok(new { message = "Password updated" });
        }

        private async Task CreateAndSendOtpAsync(User user, string purpose)
        {
            var code = System.Security.Cryptography.RandomNumberGenerator.GetInt32(100000, 999999).ToString();
            var expires = DateTime.UtcNow.AddMinutes(10);

            var oldCodes = _context.OtpCodes.Where(o => o.UserId == user.Id && o.Purpose == purpose && !o.IsUsed);
            foreach (var oc in oldCodes)
            {
                oc.IsUsed = true;
            }

            var otp = new OtpCode
            {
                UserId = user.Id,
                Code = code,
                Purpose = purpose,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = expires
            };
            _context.OtpCodes.Add(otp);
            await _context.SaveChangesAsync();

            var subject = purpose == "reset" ? "ASession: パスワードリセット用コード" : "ASession: メール認証コード";
            var body = $"認証コード: {code}\n有効期限: 10分\nもしこの要求に心当たりがない場合は、このメールを無視してください。";
            await _emailService.SendAsync(user.Email, subject, body);
        }
    }

    public class RegisterRequest
    {
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class LoginRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class LoginResponse
    {
        public string Token { get; set; } = string.Empty;
        public User User { get; set; } = null!;
    }

    public class OAuthLoginRequest
    {
        public string IdToken { get; set; } = string.Empty;
    }

    public class SendOtpRequest
    {
        public string Email { get; set; } = string.Empty;
        public string? Purpose { get; set; }
    }

    public class VerifyEmailRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }

    public class PasswordResetRequest
    {
        public string Email { get; set; } = string.Empty;
    }

    public class PerformPasswordResetRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}
