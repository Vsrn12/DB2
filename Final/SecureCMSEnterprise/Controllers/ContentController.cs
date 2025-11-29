using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SecureCMSEnterprise.Models.DTOs;
using SecureCMSEnterprise.Services;
using System.Security.Claims;

namespace SecureCMSEnterprise.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ContentController : ControllerBase
{
    private readonly IContentService _contentService;
    private readonly IAuthService _authService;

    public ContentController(IContentService contentService, IAuthService authService)
    {
        _contentService = contentService;
        _authService = authService;
    }

    /// <summary>
    /// Get all contents (published for everyone, all for authenticated users)
    /// </summary>
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetAllContents()
    {
        var userId = GetCurrentUserId();
        var contents = await _contentService.GetAllContentsAsync(userId > 0 ? userId : null);
        return Ok(contents);
    }

    /// <summary>
    /// Get content by ID
    /// </summary>
    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetContent(int id)
    {
        var content = await _contentService.GetContentByIdAsync(id);
        
        if (content == null)
        {
            return NotFound(new { message = "Content not found" });
        }

        return Ok(content);
    }

    /// <summary>
    /// Get current user's contents
    /// </summary>
    [HttpGet("my-contents")]
    public async Task<IActionResult> GetMyContents()
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        var contents = await _contentService.GetUserContentsAsync(userId);
        return Ok(contents);
    }

    /// <summary>
    /// Create new content
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateContent([FromBody] CreateContentRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        // Check permission
        if (!await _authService.HasPermissionAsync(userId, "Content", "Create"))
        {
            return Forbid();
        }

        if (string.IsNullOrEmpty(request.Title) || string.IsNullOrEmpty(request.Body))
        {
            return BadRequest(new { message = "Title and body are required" });
        }

        var content = await _contentService.CreateContentAsync(userId, request);
        
        if (content == null)
        {
            return BadRequest(new { message = "Failed to create content" });
        }

        return CreatedAtAction(nameof(GetContent), new { id = content.Id }, content);
    }

    /// <summary>
    /// Update existing content
    /// </summary>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateContent(int id, [FromBody] UpdateContentRequest request)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        var content = await _contentService.UpdateContentAsync(id, userId, request);
        
        if (content == null)
        {
            return NotFound(new { message = "Content not found or you don't have permission to update it" });
        }

        return Ok(content);
    }

    /// <summary>
    /// Delete content
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteContent(int id)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        var result = await _contentService.DeleteContentAsync(id, userId);
        
        if (!result)
        {
            return NotFound(new { message = "Content not found or you don't have permission to delete it" });
        }

        return Ok(new { message = "Content deleted successfully" });
    }

    /// <summary>
    /// Publish content (transactional)
    /// </summary>
    [HttpPost("{id}/publish")]
    public async Task<IActionResult> PublishContent(int id)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        var result = await _contentService.PublishContentAsync(id, userId);
        
        if (!result)
        {
            return BadRequest(new { message = "Failed to publish content or you don't have permission" });
        }

        return Ok(new { message = "Content published successfully" });
    }

    /// <summary>
    /// Unpublish content (transactional)
    /// </summary>
    [HttpPost("{id}/unpublish")]
    public async Task<IActionResult> UnpublishContent(int id)
    {
        var userId = GetCurrentUserId();
        if (userId == 0)
            return Unauthorized();

        var result = await _contentService.UnpublishContentAsync(id, userId);
        
        if (!result)
        {
            return BadRequest(new { message = "Failed to unpublish content or you don't have permission" });
        }

        return Ok(new { message = "Content unpublished successfully" });
    }

    private int GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(userIdClaim, out var userId) ? userId : 0;
    }
}
