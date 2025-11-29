# SecureCMS Enterprise

Sistema de Gestión de Contenidos Empresarial con Características Avanzadas de Seguridad

## 🎯 Descripción

SecureCMS Enterprise es un sistema de gestión de contenidos (CMS) robusto diseñado con seguridad empresarial en mente. Implementa encriptación a nivel de columna, control de acceso basado en roles (RBAC), auditoría completa y políticas de seguridad a nivel de fila (Row Level Security).

## ✨ Características Principales

### Seguridad Avanzada
- **Encriptación a nivel de columna** para datos sensibles (SSN, teléfonos)
- **Control de acceso basado en roles (RBAC)** con sistema flexible de permisos
- **Row Level Security (RLS)** en PostgreSQL para contenido
- **Autenticación JWT** con tokens seguros
- **Hashing de contraseñas** con BCrypt
- **Auditoría completa** con triggers automáticos en base de datos

### Funcionalidades
- ✅ Gestión de usuarios con datos encriptados
- ✅ Sistema de roles y permisos granular
- ✅ Creación, edición y publicación de contenido
- ✅ Transacciones para publicación/despublicación
- ✅ Sistema de etiquetas (tags)
- ✅ Logs de auditoría detallados
- ✅ API RESTful completa

## 🛠️ Tecnologías

- **Lenguaje**: C# (.NET 8.0)
- **Framework**: ASP.NET Core Web API
- **Base de Datos**: PostgreSQL
- **ORM**: Entity Framework Core con Npgsql
- **Autenticación**: JWT (JSON Web Tokens)
- **Documentación**: Swagger/OpenAPI

## 📋 Requisitos Previos

- .NET 8.0 SDK o superior
- PostgreSQL 14 o superior
- Visual Studio 2022 / VS Code / Rider (opcional)

## 🚀 Instalación y Configuración

### 1. Clonar el repositorio

```powershell
git clone <repository-url>
cd SecureCMSEnterprise
```

### 2. Configurar PostgreSQL

Asegúrate de tener PostgreSQL instalado y ejecutándose. Luego ejecuta el script de base de datos:

```powershell
# Conectarse a PostgreSQL
psql -U postgres

# Crear la base de datos
CREATE DATABASE securecms;

# Salir de psql
\q

# Ejecutar el script de setup
psql -U postgres -d securecms -f Database/setup_database.sql
```

### 3. Configurar appsettings.json

Actualiza el archivo `appsettings.json` con tus credenciales:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=securecms;Username=postgres;Password=TU_PASSWORD"
  },
  "Jwt": {
    "Key": "tu-clave-secreta-de-al-menos-32-caracteres-para-jwt",
    "Issuer": "SecureCMSEnterprise",
    "Audience": "SecureCMSEnterprise",
    "ExpirationInMinutes": 60
  },
  "Encryption": {
    "MasterKey": "tu-clave-maestra-de-encriptacion-32-chars"
  }
}
```

⚠️ **IMPORTANTE**: Genera claves seguras para producción. Nunca uses las claves de ejemplo.

### 4. Restaurar paquetes y ejecutar

```powershell
# Restaurar dependencias
dotnet restore

# Compilar el proyecto
dotnet build

# Ejecutar la aplicación
dotnet run
```

La API estará disponible en:
- HTTPS: `https://localhost:5001`
- HTTP: `http://localhost:5000`
- Swagger UI: `https://localhost:5001/swagger`

## 📚 Estructura del Proyecto

```
SecureCMSEnterprise/
├── Controllers/           # Controladores de API
│   ├── AuthController.cs
│   ├── ContentController.cs
│   ├── RoleController.cs
│   └── AuditController.cs
├── Data/                 # Contexto de base de datos
│   └── ApplicationDbContext.cs
├── Database/             # Scripts SQL
│   └── setup_database.sql
├── Models/               # Modelos de datos
│   ├── Entities.cs
│   └── DTOs.cs
├── Services/             # Lógica de negocio
│   ├── AuthService.cs
│   ├── ContentService.cs
│   ├── EncryptionService.cs
│   ├── AuditService.cs
│   └── RoleService.cs
├── Program.cs            # Configuración de la aplicación
└── appsettings.json      # Configuración
```

## 🔐 Sistema de Roles y Permisos

### Roles Predefinidos

1. **Administrator**: Acceso completo al sistema
2. **Editor**: Puede crear y editar todo el contenido
3. **Author**: Puede crear y editar su propio contenido
4. **Viewer**: Solo puede ver contenido publicado

### Permisos por Recurso

| Recurso | Acciones |
|---------|----------|
| User    | Create, Read, Update, Delete |
| Content | Create, Read, Update, Delete, Publish |
| Role    | Create, Read, Update, Delete |
| Audit   | Read |

## 📖 Endpoints de la API

### Autenticación

```http
POST /api/auth/register      # Registrar usuario
POST /api/auth/login         # Iniciar sesión
GET  /api/auth/permissions   # Obtener permisos del usuario
GET  /api/auth/validate      # Validar token
```

### Contenido

```http
GET    /api/content              # Listar contenidos
GET    /api/content/{id}         # Obtener contenido
GET    /api/content/my-contents  # Mis contenidos
POST   /api/content              # Crear contenido
PUT    /api/content/{id}         # Actualizar contenido
DELETE /api/content/{id}         # Eliminar contenido
POST   /api/content/{id}/publish # Publicar contenido
POST   /api/content/{id}/unpublish # Despublicar contenido
```

### Roles

```http
GET  /api/role              # Listar roles
POST /api/role              # Crear rol
POST /api/role/assign       # Asignar rol a usuario
POST /api/role/remove       # Remover rol de usuario
GET  /api/role/user/{id}    # Obtener roles de usuario
```

### Auditoría

```http
GET /api/audit                    # Listar logs de auditoría
GET /api/audit/user/{userId}      # Logs de usuario específico
GET /api/audit/content/{contentId} # Logs de contenido específico
```

## 🔍 Ejemplos de Uso

### 1. Registrar un usuario

```bash
curl -X POST https://localhost:5001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "SecureP@ssw0rd",
    "fullName": "John Doe",
    "ssn": "123-45-6789",
    "phone": "+1234567890"
  }'
```

### 2. Iniciar sesión

```bash
curl -X POST https://localhost:5001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "SecureP@ssw0rd"
  }'
```

Respuesta:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "username": "john_doe",
  "roles": ["Author"],
  "expiresAt": "2024-11-26T12:00:00Z"
}
```

### 3. Crear contenido

```bash
curl -X POST https://localhost:5001/api/content \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "title": "Mi Primer Artículo",
    "body": "Este es el contenido de mi artículo...",
    "summary": "Un resumen breve",
    "tags": ["tecnología", "seguridad"]
  }'
```

### 4. Publicar contenido (Transaccional)

```bash
curl -X POST https://localhost:5001/api/content/1/publish \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🔒 Características de Seguridad Implementadas

### 1. Encriptación a Nivel de Columna

Los datos sensibles (SSN, teléfono) se encriptan usando AES-256 antes de almacenarse:

```csharp
// En la base de datos
encrypted_ssn BYTEA  -- Datos encriptados
encrypted_phone BYTEA

// Funciones PostgreSQL
encrypt_data(data TEXT, key TEXT) RETURNS BYTEA
decrypt_data(encrypted_data BYTEA, key TEXT) RETURNS TEXT
```

### 2. Row Level Security (RLS)

PostgreSQL RLS asegura que los usuarios solo vean contenido apropiado:

```sql
-- Política: Solo ver contenido publicado o propio
CREATE POLICY content_select_policy ON contents
    FOR SELECT
    USING (
        status = 'Published' OR 
        author_id = current_setting('app.current_user_id')::INTEGER
    );
```

### 3. Auditoría Automática con Triggers

Todos los cambios se registran automáticamente:

```sql
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

### 4. Transacciones ACID

Las operaciones críticas usan transacciones:

```csharp
using var transaction = await _context.Database.BeginTransactionAsync();
try {
    // Operaciones
    await _context.SaveChangesAsync();
    await transaction.CommitAsync();
} catch {
    await transaction.RollbackAsync();
}
```

## 📊 Base de Datos

### Esquema Principal

```
users
├── id (PK)
├── username (UNIQUE, INDEXED)
├── email (UNIQUE, INDEXED)
├── password_hash
├── encrypted_ssn (ENCRYPTED)
├── encrypted_phone (ENCRYPTED)
└── is_active (INDEXED)

contents
├── id (PK)
├── title
├── slug (UNIQUE, INDEXED)
├── body
├── status (INDEXED)
├── author_id (FK, INDEXED)
└── published_at (INDEXED)

audit_logs
├── id (PK)
├── table_name (INDEXED)
├── operation (INDEXED)
├── user_id
├── old_values (JSONB)
├── new_values (JSONB)
└── timestamp (INDEXED)
```

## 🧪 Testing

Para probar la API, puedes usar:

1. **Swagger UI**: Navega a `https://localhost:5001/swagger`
2. **Postman**: Importa la colección (puedes generar desde Swagger)
3. **curl**: Usa los ejemplos proporcionados arriba

### Crear usuario administrador inicial

```sql
-- Conectarse a PostgreSQL
psql -U postgres -d securecms

-- Insertar usuario admin (password: Admin123!)
INSERT INTO users (username, email, password_hash, full_name, is_active)
VALUES ('admin', 'admin@securecms.com', 
        '$2a$11$YourBCryptHashHere', 
        'Administrator', true);

-- Asignar rol de administrador
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u, roles r
WHERE u.username = 'admin' AND r.name = 'Administrator';
```

## 🔧 Configuración Avanzada

### Variables de Entorno

Puedes usar variables de entorno en lugar de `appsettings.json`:

```powershell
$env:ConnectionStrings__DefaultConnection = "Host=localhost;..."
$env:Jwt__Key = "your-secret-key"
$env:Encryption__MasterKey = "your-encryption-key"
```

### Logging

El sistema usa logging integrado de .NET. Configura en `appsettings.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "SecureCMSEnterprise": "Debug"
    }
  }
}
```

## 📈 Mejoras Futuras

- [ ] Implementar rate limiting
- [ ] Agregar caché con Redis
- [ ] Implementar búsqueda full-text
- [ ] Agregar soporte multiidioma
- [ ] Implementar versionado de contenido
- [ ] Agregar exportación de auditoría a CSV/Excel
- [ ] Implementar notificaciones por email
- [ ] Agregar soporte para media files (imágenes, videos)

## 🤝 Contribución

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto es para fines educativos y de demostración.

## 👥 Autor

Proyecto desarrollado como parte del portafolio de desarrollo de software empresarial.

## 📞 Soporte

Para preguntas o problemas:
- Crea un issue en el repositorio
- Revisa la documentación en Swagger
- Consulta los logs de auditoría para debugging

---

**Nota de Seguridad**: Este es un proyecto educativo. Para uso en producción, asegúrate de:
- Cambiar todas las claves secretas
- Implementar HTTPS obligatorio
- Configurar CORS apropiadamente
- Realizar auditorías de seguridad
- Implementar rate limiting
- Configurar backups regulares de la base de datos
