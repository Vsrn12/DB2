using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SecureCMSEnterprise.Models.DTOs;
using SecureCMSEnterprise.Services;
using System.Security.Claims;

namespace SecureCMSEnterprise.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (string.IsNullOrEmpty(request.Username) || string.IsNullOrEmpty(request.Password))
        {
            return BadRequest(new { message = "Usuario y Contraseña" });
        }

        var result = await _authService.LoginAsync(request);
        
        if (result == null)
        {
            return Unauthorized(new { message = "Credenciales invalidas" });
        }

        return Ok(result);
    }


    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        if (string.IsNullOrEmpty(request.Username) || 
            string.IsNullOrEmpty(request.Email) || 
            string.IsNullOrEmpty(request.Password))
        {
            return BadRequest(new { message = "Username, email, and password are required" });
        }

        var user = await _authService.RegisterAsync(request);
        
        if (user == null)
        {
            return BadRequest(new { message = "User already exists or registration failed" });
        }

        return Ok(new { 
            message = "User registered successfully",
            userId = user.Id,
            username = user.Username
        });
    }


    [HttpGet("permissions")]
    [Authorize]
    public async Task<IActionResult> GetPermissions()
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        var permissions = await _authService.GetUserPermissionsAsync(userId);
        
        return Ok(new { permissions });
    }


    [HttpGet("validate")]
    [Authorize]
    public IActionResult ValidateToken()
    {
        return Ok(new { 
            valid = true,
            userId = GetCurrentUserId(),
            username = User.Identity?.Name
        });
    }

    private int GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(userIdClaim, out var userId) ? userId : 0;
    }
}
