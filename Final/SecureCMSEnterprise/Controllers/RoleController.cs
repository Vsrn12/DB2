using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SecureCMSEnterprise.Models.DTOs;
using SecureCMSEnterprise.Services;
using System.Security.Claims;

namespace SecureCMSEnterprise.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class RoleController : ControllerBase
{
    private readonly IRoleService _roleService;
    private readonly IAuthService _authService;

    public RoleController(IRoleService roleService, IAuthService authService)
    {
        _roleService = roleService;
        _authService = authService;
    }

    /// <summary>
    /// Get all roles
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAllRoles()
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(userId, "Role", "Read"))
        {
            return Forbid();
        }

        var roles = await _roleService.GetAllRolesAsync();
        return Ok(roles);
    }

    /// <summary>
    /// Create new role
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateRole([FromBody] CreateRoleRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(userId, "Role", "Create"))
        {
            return Forbid();
        }

        if (string.IsNullOrEmpty(request.Name))
        {
            return BadRequest(new { message = "Role name is required" });
        }

        var role = await _roleService.CreateRoleAsync(request);
        
        if (role == null)
        {
            return BadRequest(new { message = "Role already exists or creation failed" });
        }

        return CreatedAtAction(nameof(GetAllRoles), new { id = role.Id }, role);
    }

    /// <summary>
    /// Assign role to user
    /// </summary>
    [HttpPost("assign")]
    public async Task<IActionResult> AssignRole([FromBody] AssignRoleRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(userId, "Role", "Update"))
        {
            return Forbid();
        }

        var result = await _roleService.AssignRoleToUserAsync(request.UserId, request.RoleId);
        
        if (!result)
        {
            return BadRequest(new { message = "Failed to assign role (may already be assigned or invalid IDs)" });
        }

        return Ok(new { message = "Role assigned successfully" });
    }

    /// <summary>
    /// Remove role from user
    /// </summary>
    [HttpPost("remove")]
    public async Task<IActionResult> RemoveRole([FromBody] AssignRoleRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(userId, "Role", "Update"))
        {
            return Forbid();
        }

        var result = await _roleService.RemoveRoleFromUserAsync(request.UserId, request.RoleId);
        
        if (!result)
        {
            return BadRequest(new { message = "Failed to remove role" });
        }

        return Ok(new { message = "Role removed successfully" });
    }

    /// <summary>
    /// Get user roles
    /// </summary>
    [HttpGet("user/{userId}")]
    public async Task<IActionResult> GetUserRoles(int userId)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(currentUserId, "User", "Read"))
        {
            return Forbid();
        }

        var roles = await _roleService.GetUserRolesAsync(userId);
        return Ok(new { userId, roles });
    }

    private int GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(userIdClaim, out var userId) ? userId : 0;
    }
}
