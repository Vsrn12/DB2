using Microsoft.EntityFrameworkCore;
using SecureCMSEnterprise.Data;
using SecureCMSEnterprise.Models;
using SecureCMSEnterprise.Models.DTOs;

namespace SecureCMSEnterprise.Services;

public interface IAuditService
{
    Task<List<AuditLogResponse>> GetAuditLogsAsync(string? tableName = null, int? userId = null, int pageSize = 100);
    Task<List<AuditLogResponse>> GetUserAuditLogsAsync(int userId, int pageSize = 50);
    Task<List<AuditLogResponse>> GetContentAuditLogsAsync(int contentId, int pageSize = 50);
}

public class AuditService : IAuditService
{
    private readonly ApplicationDbContext _context;

    public AuditService(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<List<AuditLogResponse>> GetAuditLogsAsync(string? tableName = null, int? userId = null, int pageSize = 100)
    {
        var query = _context.AuditLogs.AsQueryable();

        if (!string.IsNullOrEmpty(tableName))
        {
            query = query.Where(al => al.TableName == tableName);
        }

        if (userId.HasValue)
        {
            query = query.Where(al => al.UserId == userId.Value);
        }

        var logs = await query
            .OrderByDescending(al => al.Timestamp)
            .Take(pageSize)
            .ToListAsync();

        return logs.Select(MapToResponse).ToList();
    }

    public async Task<List<AuditLogResponse>> GetUserAuditLogsAsync(int userId, int pageSize = 50)
    {
        var logs = await _context.AuditLogs
            .Where(al => al.UserId == userId)
            .OrderByDescending(al => al.Timestamp)
            .Take(pageSize)
            .ToListAsync();

        return logs.Select(MapToResponse).ToList();
    }

    public async Task<List<AuditLogResponse>> GetContentAuditLogsAsync(int contentId, int pageSize = 50)
    {
        var logs = await _context.AuditLogs
            .Where(al => al.TableName == "contents" && al.NewValues.Contains($"\"id\": {contentId}"))
            .OrderByDescending(al => al.Timestamp)
            .Take(pageSize)
            .ToListAsync();

        return logs.Select(MapToResponse).ToList();
    }

    private static AuditLogResponse MapToResponse(AuditLog log)
    {
        return new AuditLogResponse
        {
            Id = log.Id,
            TableName = log.TableName,
            Operation = log.Operation,
            Username = log.Username,
            Timestamp = log.Timestamp,
            IpAddress = log.IpAddress
        };
    }
}
