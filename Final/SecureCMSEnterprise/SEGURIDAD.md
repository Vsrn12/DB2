# Características de Seguridad - SecureCMS Enterprise

## 🔐 Resumen de Implementaciones de Seguridad

Este documento detalla todas las características de seguridad implementadas en SecureCMS Enterprise.

## 1. Encriptación a Nivel de Columna

### Implementación

Los datos sensibles se encriptan antes de almacenarse en la base de datos usando AES-256.

**Columnas Encriptadas:**
- `encrypted_ssn` - Números de Seguro Social
- `encrypted_phone` - Números de teléfono

**Código C#:**
```csharp
public class EncryptionService : IEncryptionService
{
    private readonly byte[] _key;
    private readonly byte[] _iv;
    
    public byte[] EncryptToBytes(string plainText)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = _iv;
        aes.Mode = CipherMode.CBC;
        aes.Padding = PaddingMode.PKCS7;
        
        using var encryptor = aes.CreateEncryptor();
        var plainBytes = Encoding.UTF8.GetBytes(plainText);
        return encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
    }
}
```

**Funciones PostgreSQL:**
```sql
CREATE OR REPLACE FUNCTION encrypt_data(data TEXT, key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, key);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### Uso

```csharp
// Al registrar un usuario
if (!string.IsNullOrEmpty(request.SSN))
{
    user.EncryptedSSN = Convert.ToBase64String(
        _encryptionService.EncryptToBytes(request.SSN)
    );
}
```

## 2. Control de Acceso Basado en Roles (RBAC)

### Arquitectura

```
User (1) ←→ (N) UserRole (N) ←→ (1) Role
                                    ↓
                            RolePermission (N)
                                    ↓
                            Permission (1)
```

### Roles Predefinidos

| Rol | Descripción | Permisos |
|-----|-------------|----------|
| Administrator | Acceso total | Todos los permisos |
| Editor | Gestión de contenido | Content.* |
| Author | Creación de contenido propio | Content.Create, Read, Update |
| Viewer | Solo lectura | *.Read |

### Permisos Disponibles

**Formato:** `Recurso:Acción`

- User:Create, User:Read, User:Update, User:Delete
- Content:Create, Content:Read, Content:Update, Content:Delete, Content:Publish
- Role:Create, Role:Read, Role:Update, Role:Delete
- Audit:Read

### Implementación

```csharp
public async Task<bool> HasPermissionAsync(int userId, string resource, string action)
{
    return await _context.UserRoles
        .Where(ur => ur.UserId == userId)
        .SelectMany(ur => ur.Role.RolePermissions)
        .AnyAsync(rp => 
            rp.Permission.Resource == resource && 
            rp.Permission.Action == action
        );
}
```

### Uso en Controladores

```csharp
[HttpPost]
public async Task<IActionResult> CreateContent([FromBody] CreateContentRequest request)
{
    var userId = GetCurrentUserId();
    
    // Verificar permiso
    if (!await _authService.HasPermissionAsync(userId, "Content", "Create"))
    {
        return Forbid();
    }
    
    // Continuar con la lógica...
}
```

## 3. Row Level Security (RLS)

### Configuración PostgreSQL

```sql
-- Habilitar RLS en la tabla contents
ALTER TABLE contents ENABLE ROW LEVEL SECURITY;

-- Política: Ver solo contenido publicado o propio
CREATE POLICY content_select_policy ON contents
    FOR SELECT
    USING (
        status = 'Published' OR 
        author_id = COALESCE(current_setting('app.current_user_id', true)::INTEGER, -1)
    );

-- Política: Actualizar solo contenido propio
CREATE POLICY content_update_policy ON contents
    FOR UPDATE
    USING (author_id = COALESCE(current_setting('app.current_user_id', true)::INTEGER, -1));
```

### Establecer Contexto de Usuario

```sql
-- Función para establecer usuario actual
CREATE OR REPLACE FUNCTION set_current_user(user_id INTEGER, username VARCHAR)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::TEXT, false);
    PERFORM set_config('app.current_username', username, false);
END;
$$ LANGUAGE plpgsql;
```

### Cómo Funciona

1. Antes de ejecutar consultas, se establece el contexto del usuario
2. PostgreSQL aplica automáticamente las políticas RLS
3. Los usuarios solo ven/modifican datos según las políticas

**Ejemplo:**

```sql
-- Establecer usuario actual
SELECT set_current_user(5, 'john_doe');

-- Esta consulta solo retornará:
-- 1. Contenido con status='Published'
-- 2. Contenido donde author_id=5
SELECT * FROM contents;
```

## 4. Auditoría Completa con Triggers

### Implementación

**Trigger Function:**
```sql
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    old_data JSONB;
    new_data JSONB;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        old_data := to_jsonb(OLD);
        new_data := NULL;
    ELSIF (TG_OP = 'UPDATE') THEN
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
    ELSIF (TG_OP = 'INSERT') THEN
        old_data := NULL;
        new_data := to_jsonb(NEW);
    END IF;
    
    INSERT INTO audit_logs (
        table_name, operation, user_id, username, 
        old_values, new_values
    ) VALUES (
        TG_TABLE_NAME, TG_OP, 
        current_setting('app.current_user_id')::INTEGER,
        current_setting('app.current_username'),
        old_data, new_data
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Triggers en Tablas:**
```sql
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_contents_trigger
    AFTER INSERT OR UPDATE OR DELETE ON contents
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

### Datos Capturados

Cada entrada de auditoría contiene:

- **table_name**: Tabla afectada
- **operation**: INSERT, UPDATE, o DELETE
- **user_id**: ID del usuario que realizó la acción
- **username**: Nombre del usuario
- **old_values**: Valores anteriores (JSONB)
- **new_values**: Valores nuevos (JSONB)
- **timestamp**: Fecha y hora
- **ip_address**: Dirección IP (si se configura)
- **user_agent**: Navegador/cliente (si se configura)

### Consultar Auditoría

```sql
-- Ver todos los cambios en usuarios
SELECT * FROM audit_logs WHERE table_name = 'users';

-- Ver acciones de un usuario específico
SELECT * FROM audit_logs WHERE username = 'admin';

-- Ver cambios en las últimas 24 horas
SELECT * FROM audit_logs 
WHERE timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;
```

## 5. Autenticación JWT

### Configuración

```csharp
var jwtKey = builder.Configuration["Jwt:Key"];
var key = Encoding.UTF8.GetBytes(jwtKey);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(key),
        ValidateIssuer = true,
        ValidIssuer = configuration["Jwt:Issuer"],
        ValidateAudience = true,
        ValidAudience = configuration["Jwt:Audience"],
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };
});
```

### Generación de Tokens

```csharp
private string GenerateJwtToken(User user)
{
    var claims = new List<Claim>
    {
        new(ClaimTypes.NameIdentifier, user.Id.ToString()),
        new(ClaimTypes.Name, user.Username),
        new(ClaimTypes.Email, user.Email)
    };
    
    // Agregar roles como claims
    var roles = _context.UserRoles
        .Where(ur => ur.UserId == user.Id)
        .Select(ur => ur.Role.Name)
        .ToList();
    
    claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));
    
    var tokenDescriptor = new SecurityTokenDescriptor
    {
        Subject = new ClaimsIdentity(claims),
        Expires = DateTime.UtcNow.AddMinutes(60),
        SigningCredentials = new SigningCredentials(
            new SymmetricSecurityKey(key), 
            SecurityAlgorithms.HmacSha256Signature
        )
    };
    
    return tokenHandler.WriteToken(tokenHandler.CreateToken(tokenDescriptor));
}
```

### Estructura del Token

**Header:**
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

**Payload:**
```json
{
  "nameid": "5",
  "unique_name": "john_doe",
  "email": "john@example.com",
  "role": ["Author"],
  "exp": 1700000000,
  "iss": "SecureCMSEnterprise",
  "aud": "SecureCMSEnterprise"
}
```

## 6. Hash de Contraseñas con BCrypt

### Implementación

```csharp
// Al registrar
user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

// Al validar
bool isValid = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);
```

### Características

- **Work Factor**: 11 (por defecto)
- **Salt**: Generado automáticamente
- **Algoritmo**: BCrypt (basado en Blowfish)
- **Resistente a**: Rainbow tables, fuerza bruta

### Ejemplo de Hash

```
Contraseña: "MySecureP@ss123"
Hash: "$2a$11$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy"
```

## 7. Transacciones ACID

### Implementación

```csharp
public async Task<bool> PublishContentAsync(int contentId, int userId)
{
    using var transaction = await _context.Database.BeginTransactionAsync();
    
    try
    {
        var content = await _context.Contents.FindAsync(contentId);
        
        // Verificar permisos
        if (!CanPublish(content, userId))
            return false;
        
        // Actualizar estado
        content.Status = "Published";
        content.PublishedAt = DateTime.UtcNow;
        
        await _context.SaveChangesAsync();
        
        // Commit si todo fue exitoso
        await transaction.CommitAsync();
        return true;
    }
    catch
    {
        // Rollback en caso de error
        await transaction.RollbackAsync();
        return false;
    }
}
```

### Garantías

- **Atomicity**: Todo o nada
- **Consistency**: Datos consistentes
- **Isolation**: Transacciones aisladas
- **Durability**: Cambios permanentes

## 8. Índices para Performance

### Índices Implementados

```sql
-- Usuarios
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Contenidos
CREATE INDEX idx_contents_slug ON contents(slug);
CREATE INDEX idx_contents_status ON contents(status);
CREATE INDEX idx_contents_author_id ON contents(author_id);
CREATE INDEX idx_contents_published_at ON contents(published_at);

-- Auditoría
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_operation ON audit_logs(operation);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
```

### Beneficios

- Búsquedas más rápidas
- Joins optimizados
- Ordenamiento eficiente
- Queries de auditoría rápidas

## 🔒 Mejores Prácticas de Seguridad

1. **Nunca** almacenes contraseñas en texto plano
2. **Siempre** usa HTTPS en producción
3. **Rota** las claves secretas periódicamente
4. **Revisa** los logs de auditoría regularmente
5. **Limita** el tamaño de los tokens JWT
6. **Implementa** rate limiting
7. **Valida** todas las entradas del usuario
8. **Usa** prepared statements (Entity Framework lo hace automáticamente)
9. **Mantén** las dependencias actualizadas
10. **Realiza** backups regulares

## 📊 Checklist de Seguridad

- [x] Encriptación de datos sensibles
- [x] Control de acceso basado en roles
- [x] Row Level Security
- [x] Auditoría completa
- [x] Autenticación JWT
- [x] Hash de contraseñas
- [x] Transacciones ACID
- [x] Índices de base de datos
- [x] Validación de entrada
- [x] CORS configurado
- [ ] Rate limiting (pendiente)
- [ ] HTTPS obligatorio (configurar en producción)
- [ ] Rotación de claves (implementar política)

## 🚨 Consideraciones de Producción

### Antes de Desplegar

1. Cambiar todas las claves secretas
2. Habilitar HTTPS
3. Configurar firewall de base de datos
4. Implementar rate limiting
5. Configurar backups automáticos
6. Establecer política de rotación de claves
7. Configurar logging centralizado
8. Implementar monitoreo
9. Realizar penetration testing
10. Configurar alertas de seguridad
