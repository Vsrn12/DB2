using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SecureCMSEnterprise.Services;
using System.Security.Claims;

namespace SecureCMSEnterprise.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AuditController : ControllerBase
{
    private readonly IAuditService _auditService;
    private readonly IAuthService _authService;

    public AuditController(IAuditService auditService, IAuthService authService)
    {
        _auditService = auditService;
        _authService = authService;
    }

    /// <summary>
    /// Get audit logs with optional filters
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAuditLogs(
        [FromQuery] string? tableName = null,
        [FromQuery] int? userId = null,
        [FromQuery] int pageSize = 100)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(currentUserId, "Audit", "Read"))
        {
            return Forbid();
        }

        var logs = await _auditService.GetAuditLogsAsync(tableName, userId, pageSize);
        return Ok(logs);
    }

    /// <summary>
    /// Get audit logs for specific user
    /// </summary>
    [HttpGet("user/{userId}")]
    public async Task<IActionResult> GetUserAuditLogs(int userId, [FromQuery] int pageSize = 50)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(currentUserId, "Audit", "Read"))
        {
            return Forbid();
        }

        var logs = await _auditService.GetUserAuditLogsAsync(userId, pageSize);
        return Ok(logs);
    }

    /// <summary>
    /// Get audit logs for specific content
    /// </summary>
    [HttpGet("content/{contentId}")]
    public async Task<IActionResult> GetContentAuditLogs(int contentId, [FromQuery] int pageSize = 50)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(currentUserId, "Audit", "Read"))
        {
            return Forbid();
        }

        var logs = await _auditService.GetContentAuditLogsAsync(contentId, pageSize);
        return Ok(logs);
    }

    private int GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(userIdClaim, out var userId) ? userId : 0;
    }
}
