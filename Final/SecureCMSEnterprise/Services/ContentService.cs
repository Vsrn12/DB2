using Microsoft.EntityFrameworkCore;
using SecureCMSEnterprise.Data;
using SecureCMSEnterprise.Models;
using SecureCMSEnterprise.Models.DTOs;

namespace SecureCMSEnterprise.Services;

public interface IContentService
{
    Task<Content?> CreateContentAsync(int authorId, CreateContentRequest request);
    Task<Content?> UpdateContentAsync(int contentId, int userId, UpdateContentRequest request);
    Task<bool> DeleteContentAsync(int contentId, int userId);
    Task<Content?> GetContentByIdAsync(int contentId);
    Task<List<ContentResponse>> GetAllContentsAsync(int? userId = null);
    Task<bool> PublishContentAsync(int contentId, int userId);
    Task<bool> UnpublishContentAsync(int contentId, int userId);
    Task<List<ContentResponse>> GetUserContentsAsync(int userId);
}

public class ContentService : IContentService
{
    private readonly ApplicationDbContext _context;
    private readonly IAuthService _authService;

    public ContentService(ApplicationDbContext context, IAuthService authService)
    {
        _context = context;
        _authService = authService;
    }

    public async Task<Content?> CreateContentAsync(int authorId, CreateContentRequest request)
    {
        var slug = GenerateSlug(request.Title);
        
        // Ensure unique slug
        var baseSlug = slug;
        var counter = 1;
        while (await _context.Contents.AnyAsync(c => c.Slug == slug))
        {
            slug = $"{baseSlug}-{counter++}";
        }

        var content = new Content
        {
            Title = request.Title,
            Slug = slug,
            Body = request.Body,
            Summary = request.Summary,
            AuthorId = authorId,
            Status = "Draft",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Contents.Add(content);
        await _context.SaveChangesAsync();

        // Add tags if provided
        if (request.Tags != null && request.Tags.Any())
        {
            await AddTagsToContentAsync(content.Id, request.Tags);
        }

        return content;
    }

    public async Task<Content?> UpdateContentAsync(int contentId, int userId, UpdateContentRequest request)
    {
        var content = await _context.Contents.FindAsync(contentId);
        
        if (content == null)
            return null;

        // Check if user owns the content or has permission
        var canUpdate = content.AuthorId == userId || 
                       await _authService.HasPermissionAsync(userId, "Content", "Update");
        
        if (!canUpdate)
            return null;

        if (!string.IsNullOrEmpty(request.Title))
        {
            content.Title = request.Title;
            content.Slug = GenerateSlug(request.Title);
        }

        if (!string.IsNullOrEmpty(request.Body))
            content.Body = request.Body;

        if (request.Summary != null)
            content.Summary = request.Summary;

        content.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Update tags if provided
        if (request.Tags != null)
        {
            // Remove existing tags
            var existingTags = await _context.ContentTags
                .Where(ct => ct.ContentId == contentId)
                .ToListAsync();
            _context.ContentTags.RemoveRange(existingTags);
            
            // Add new tags
            await AddTagsToContentAsync(contentId, request.Tags);
        }

        return content;
    }

    public async Task<bool> DeleteContentAsync(int contentId, int userId)
    {
        var content = await _context.Contents.FindAsync(contentId);
        
        if (content == null)
            return false;

        // Check if user owns the content or has permission
        var canDelete = content.AuthorId == userId || 
                       await _authService.HasPermissionAsync(userId, "Content", "Delete");
        
        if (!canDelete)
            return false;

        _context.Contents.Remove(content);
        await _context.SaveChangesAsync();

        return true;
    }

    public async Task<Content?> GetContentByIdAsync(int contentId)
    {
        return await _context.Contents
            .Include(c => c.Author)
            .Include(c => c.ContentTags)
                .ThenInclude(ct => ct.Tag)
            .FirstOrDefaultAsync(c => c.Id == contentId);
    }

    public async Task<List<ContentResponse>> GetAllContentsAsync(int? userId = null)
    {
        var query = _context.Contents
            .Include(c => c.Author)
            .Include(c => c.ContentTags)
                .ThenInclude(ct => ct.Tag)
            .AsQueryable();

        // If userId is provided, show all their content plus published content
        if (userId.HasValue)
        {
            query = query.Where(c => c.Status == "Published" || c.AuthorId == userId.Value);
        }
        else
        {
            // Only show published content for anonymous users
            query = query.Where(c => c.Status == "Published");
        }

        var contents = await query
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        return contents.Select(MapToResponse).ToList();
    }

    public async Task<List<ContentResponse>> GetUserContentsAsync(int userId)
    {
        var contents = await _context.Contents
            .Include(c => c.Author)
            .Include(c => c.ContentTags)
                .ThenInclude(ct => ct.Tag)
            .Where(c => c.AuthorId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        return contents.Select(MapToResponse).ToList();
    }

    public async Task<bool> PublishContentAsync(int contentId, int userId)
    {
        using var transaction = await _context.Database.BeginTransactionAsync();
        
        try
        {
            var content = await _context.Contents.FindAsync(contentId);
            
            if (content == null)
                return false;

            // Check if user can publish
            var canPublish = content.AuthorId == userId || 
                           await _authService.HasPermissionAsync(userId, "Content", "Publish");
            
            if (!canPublish)
                return false;

            content.Status = "Published";
            content.PublishedAt = DateTime.UtcNow;
            content.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return true;
        }
        catch
        {
            await transaction.RollbackAsync();
            return false;
        }
    }

    public async Task<bool> UnpublishContentAsync(int contentId, int userId)
    {
        using var transaction = await _context.Database.BeginTransactionAsync();
        
        try
        {
            var content = await _context.Contents.FindAsync(contentId);
            
            if (content == null)
                return false;

            // Check if user can unpublish
            var canUnpublish = content.AuthorId == userId || 
                             await _authService.HasPermissionAsync(userId, "Content", "Publish");
            
            if (!canUnpublish)
                return false;

            content.Status = "Draft";
            content.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return true;
        }
        catch
        {
            await transaction.RollbackAsync();
            return false;
        }
    }

    private async Task AddTagsToContentAsync(int contentId, List<string> tagNames)
    {
        foreach (var tagName in tagNames)
        {
            var tagSlug = GenerateSlug(tagName);
            
            var tag = await _context.Tags.FirstOrDefaultAsync(t => t.Slug == tagSlug);
            if (tag == null)
            {
                tag = new Tag
                {
                    Name = tagName,
                    Slug = tagSlug
                };
                _context.Tags.Add(tag);
                await _context.SaveChangesAsync();
            }

            if (!await _context.ContentTags.AnyAsync(ct => ct.ContentId == contentId && ct.TagId == tag.Id))
            {
                _context.ContentTags.Add(new ContentTag
                {
                    ContentId = contentId,
                    TagId = tag.Id
                });
            }
        }

        await _context.SaveChangesAsync();
    }

    private static string GenerateSlug(string text)
    {
        return text.ToLowerInvariant()
            .Replace(" ", "-")
            .Replace("á", "a").Replace("é", "e").Replace("í", "i").Replace("ó", "o").Replace("ú", "u")
            .Replace("ñ", "n")
            .Trim();
    }

    private static ContentResponse MapToResponse(Content content)
    {
        return new ContentResponse
        {
            Id = content.Id,
            Title = content.Title,
            Slug = content.Slug,
            Body = content.Body,
            Summary = content.Summary,
            Status = content.Status,
            AuthorName = content.Author?.Username ?? "Unknown",
            CreatedAt = content.CreatedAt,
            UpdatedAt = content.UpdatedAt,
            PublishedAt = content.PublishedAt,
            ViewCount = content.ViewCount,
            Tags = content.ContentTags.Select(ct => ct.Tag.Name).ToList()
        };
    }
}
