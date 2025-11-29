# Guía de Instalación y Uso - SecureCMS Enterprise

## 🚀 Inicio Rápido

### Instalación en 5 pasos

1. **Instalar PostgreSQL** (si no lo tienes)
   - Descarga desde: https://www.postgresql.org/download/
   - Durante la instalación, recuerda la contraseña de `postgres`

2. **Configurar la base de datos**
   ```powershell
   # Crear la base de datos
   psql -U postgres -c "CREATE DATABASE securecms;"
   
   # Ejecutar el script de setup
   psql -U postgres -d securecms -f Database/setup_database.sql
   ```

3. **Configurar credenciales**
   - Abre `appsettings.json`
   - Cambia la contraseña de PostgreSQL
   - Genera claves seguras para JWT y encriptación

4. **Compilar y ejecutar**
   ```powershell
   dotnet restore
   dotnet build
   dotnet run
   ```

5. **Abrir Swagger UI**
   - Navega a: https://localhost:5001/swagger
   - Comienza a probar los endpoints

## 📝 Uso Básico

### Flujo de Trabajo Típico

1. **Registrar un usuario**
   - Endpoint: `POST /api/auth/register`
   - Se le asignará automáticamente el rol "Author"

2. **Iniciar sesión**
   - Endpoint: `POST /api/auth/login`
   - Guarda el token JWT retornado

3. **Crear contenido**
   - Endpoint: `POST /api/content`
   - Usa el token en el header: `Authorization: Bearer {token}`

4. **Publicar contenido**
   - Endpoint: `POST /api/content/{id}/publish`
   - Se ejecuta como transacción atómica

5. **Ver logs de auditoría**
   - Endpoint: `GET /api/audit` (requiere rol Administrator)

## 🔐 Gestión de Seguridad

### Generar Claves Seguras

```powershell
# Generar clave aleatoria de 32 caracteres
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

### Crear Usuario Administrador

```sql
-- 1. Primero, genera un hash BCrypt de tu contraseña
-- Usa una herramienta online o el siguiente código C#

-- 2. Inserta el usuario
INSERT INTO users (username, email, password_hash, full_name, is_active)
VALUES ('admin', 'admin@securecms.com', 
        '$2a$11$TU_HASH_BCRYPT_AQUI', 
        'System Administrator', true);

-- 3. Asignar rol de administrador
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u, roles r
WHERE u.username = 'admin' AND r.name = 'Administrator';
```

## 🧪 Pruebas con Swagger

1. Abre https://localhost:5001/swagger
2. Expande `POST /api/auth/register`
3. Click en "Try it out"
4. Ingresa los datos de prueba:
   ```json
   {
     "username": "testuser",
     "email": "test@example.com",
     "password": "Test123!",
     "fullName": "Test User"
   }
   ```
5. Click "Execute"
6. Copia el token del login
7. Click en "Authorize" (candado verde arriba)
8. Pega: `Bearer {tu-token}`
9. Ahora puedes probar endpoints protegidos

## 📊 Verificar Auditoría

```sql
-- Ver todos los logs de auditoría
SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 10;

-- Ver cambios en usuarios
SELECT * FROM audit_logs WHERE table_name = 'users';

-- Ver cambios de un usuario específico
SELECT * FROM audit_logs WHERE username = 'admin';
```

## 🛠️ Troubleshooting

### Problema: No se puede conectar a PostgreSQL

**Solución**:
```powershell
# Verificar que PostgreSQL esté corriendo
Get-Service postgresql*

# Si no está corriendo, iniciarlo
Start-Service postgresql-x64-14  # Ajusta el nombre según tu versión
```

### Problema: Error "JWT Key not configured"

**Solución**: Asegúrate que `appsettings.json` tenga la clave JWT configurada correctamente.

### Problema: "Unauthorized" en todos los endpoints

**Solución**: 
1. Verifica que el token no haya expirado
2. Asegúrate de incluir "Bearer " antes del token
3. Verifica que el usuario tenga los permisos necesarios

## 📚 Recursos Adicionales

- [Documentación de ASP.NET Core](https://docs.microsoft.com/aspnet/core)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [JWT.io](https://jwt.io/) - Para decodificar tokens JWT
- [BCrypt Calculator](https://bcrypt-generator.com/) - Para generar hashes

## 💡 Tips y Mejores Prácticas

1. **Nunca** compartas tus claves secretas
2. Usa contraseñas fuertes en producción
3. Habilita HTTPS en producción
4. Realiza backups regulares de la base de datos
5. Revisa los logs de auditoría periódicamente
6. Actualiza dependencias regularmente

## 🔄 Actualización de la Base de Datos

Si necesitas agregar nuevas columnas o tablas:

```powershell
# Crear migración (si usas EF Core Migrations)
dotnet ef migrations add NombreDeMigracion

# Aplicar migración
dotnet ef database update
```

## 📞 Obtener Ayuda

Si encuentras problemas:

1. Revisa los logs en la consola
2. Verifica la configuración en `appsettings.json`
3. Consulta la documentación en el README.md
4. Revisa los logs de auditoría en la base de datos
