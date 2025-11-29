# SecureCMS Enterprise - API Testing Collection

## Postman/Thunder Client Collection

### Variables de Entorno

```json
{
  "baseUrl": "https://localhost:5001/api",
  "token": "",
  "userId": "",
  "contentId": ""
}
```

---

## 1. Autenticación

### 1.1 Registrar Usuario

**Request:**
```http
POST {{baseUrl}}/auth/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "SecureP@ss123",
  "fullName": "John Doe",
  "ssn": "123-45-6789",
  "phone": "+1234567890"
}
```

**Expected Response (201):**
```json
{
  "message": "User registered successfully",
  "userId": 1,
  "username": "john_doe"
}
```

---

### 1.2 Login

**Request:**
```http
POST {{baseUrl}}/auth/login
Content-Type: application/json

{
  "username": "john_doe",
  "password": "SecureP@ss123"
}
```

**Expected Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "username": "john_doe",
  "roles": ["Author"],
  "expiresAt": "2024-11-26T12:00:00Z"
}
```

**Script:** Guarda el token
```javascript
// Para Postman
pm.environment.set("token", pm.response.json().token);
```

---

### 1.3 Obtener Permisos

**Request:**
```http
GET {{baseUrl}}/auth/permissions
Authorization: Bearer {{token}}
```

**Expected Response (200):**
```json
{
  "permissions": [
    "Content:Create",
    "Content:Read",
    "Content:Update"
  ]
}
```

---

### 1.4 Validar Token

**Request:**
```http
GET {{baseUrl}}/auth/validate
Authorization: Bearer {{token}}
```

**Expected Response (200):**
```json
{
  "valid": true,
  "userId": 1,
  "username": "john_doe"
}
```

---

## 2. Contenido

### 2.1 Crear Contenido

**Request:**
```http
POST {{baseUrl}}/content
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "title": "Mi Primer Artículo",
  "body": "Este es el contenido completo de mi artículo sobre seguridad en aplicaciones web...",
  "summary": "Introducción a la seguridad web",
  "tags": ["seguridad", "web", "tutorial"]
}
```

**Expected Response (201):**
```json
{
  "id": 1,
  "title": "Mi Primer Artículo",
  "slug": "mi-primer-articulo",
  "body": "Este es el contenido completo...",
  "summary": "Introducción a la seguridad web",
  "status": "Draft",
  "authorId": 1,
  "createdAt": "2024-11-26T10:00:00Z",
  "updatedAt": "2024-11-26T10:00:00Z"
}
```

---

### 2.2 Listar Todos los Contenidos

**Request:**
```http
GET {{baseUrl}}/content
```

**Expected Response (200):**
```json
[
  {
    "id": 1,
    "title": "Mi Primer Artículo",
    "slug": "mi-primer-articulo",
    "body": "...",
    "status": "Published",
    "authorName": "john_doe",
    "createdAt": "2024-11-26T10:00:00Z",
    "tags": ["seguridad", "web"]
  }
]
```

---

### 2.3 Obtener Contenido por ID

**Request:**
```http
GET {{baseUrl}}/content/1
```

---

### 2.4 Mis Contenidos

**Request:**
```http
GET {{baseUrl}}/content/my-contents
Authorization: Bearer {{token}}
```

---

### 2.5 Actualizar Contenido

**Request:**
```http
PUT {{baseUrl}}/content/1
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "title": "Mi Primer Artículo (Actualizado)",
  "body": "Contenido actualizado...",
  "tags": ["seguridad", "web", "actualizado"]
}
```

---

### 2.6 Publicar Contenido (Transaccional)

**Request:**
```http
POST {{baseUrl}}/content/1/publish
Authorization: Bearer {{token}}
```

**Expected Response (200):**
```json
{
  "message": "Content published successfully"
}
```

---

### 2.7 Despublicar Contenido (Transaccional)

**Request:**
```http
POST {{baseUrl}}/content/1/unpublish
Authorization: Bearer {{token}}
```

---

### 2.8 Eliminar Contenido

**Request:**
```http
DELETE {{baseUrl}}/content/1
Authorization: Bearer {{token}}
```

---

## 3. Roles

### 3.1 Listar Roles

**Request:**
```http
GET {{baseUrl}}/role
Authorization: Bearer {{token}}
```

**Expected Response (200):**
```json
[
  {
    "id": 1,
    "name": "Administrator",
    "description": "Full system access",
    "rolePermissions": [...]
  }
]
```

---

### 3.2 Crear Rol

**Request:**
```http
POST {{baseUrl}}/role
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "name": "Moderator",
  "description": "Can moderate content",
  "permissionIds": [5, 6, 7, 8, 9]
}
```

---

### 3.3 Asignar Rol a Usuario

**Request:**
```http
POST {{baseUrl}}/role/assign
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "userId": 2,
  "roleId": 2
}
```

---

### 3.4 Remover Rol de Usuario

**Request:**
```http
POST {{baseUrl}}/role/remove
Authorization: Bearer {{token}}
Content-Type: application/json

{
  "userId": 2,
  "roleId": 2
}
```

---

### 3.5 Obtener Roles de Usuario

**Request:**
```http
GET {{baseUrl}}/role/user/1
Authorization: Bearer {{token}}
```

---

## 4. Auditoría

### 4.1 Listar Logs de Auditoría

**Request:**
```http
GET {{baseUrl}}/audit?pageSize=50
Authorization: Bearer {{token}}
```

**Expected Response (200):**
```json
[
  {
    "id": 1,
    "tableName": "contents",
    "operation": "INSERT",
    "username": "john_doe",
    "timestamp": "2024-11-26T10:00:00Z",
    "ipAddress": "192.168.1.1"
  }
]
```

---

### 4.2 Logs de Auditoría por Tabla

**Request:**
```http
GET {{baseUrl}}/audit?tableName=users&pageSize=20
Authorization: Bearer {{token}}
```

---

### 4.3 Logs de Auditoría por Usuario

**Request:**
```http
GET {{baseUrl}}/audit/user/1?pageSize=30
Authorization: Bearer {{token}}
```

---

### 4.4 Logs de Auditoría de Contenido

**Request:**
```http
GET {{baseUrl}}/audit/content/1?pageSize=20
Authorization: Bearer {{token}}
```

---

## Escenarios de Prueba

### Escenario 1: Flujo Completo de Usuario

1. Registrar usuario → `POST /auth/register`
2. Login → `POST /auth/login` (guardar token)
3. Ver permisos → `GET /auth/permissions`
4. Crear contenido → `POST /content`
5. Publicar contenido → `POST /content/{id}/publish`
6. Ver contenido publicado → `GET /content/{id}`

---

### Escenario 2: Gestión de Roles (Requiere Admin)

1. Login como admin
2. Crear nuevo rol → `POST /role`
3. Asignar rol a usuario → `POST /role/assign`
4. Verificar roles del usuario → `GET /role/user/{userId}`

---

### Escenario 3: Auditoría

1. Realizar varias acciones (crear, actualizar, eliminar)
2. Ver logs generales → `GET /audit`
3. Ver logs específicos de tabla → `GET /audit?tableName=contents`
4. Ver logs de usuario → `GET /audit/user/{userId}`

---

## Códigos de Estado HTTP

| Código | Significado |
|--------|-------------|
| 200 | OK - Solicitud exitosa |
| 201 | Created - Recurso creado |
| 400 | Bad Request - Datos inválidos |
| 401 | Unauthorized - No autenticado |
| 403 | Forbidden - No autorizado |
| 404 | Not Found - Recurso no encontrado |
| 500 | Internal Server Error - Error del servidor |

---

## Tips de Testing

1. **Orden de Pruebas:**
   - Primero: Autenticación
   - Segundo: Operaciones CRUD
   - Tercero: Auditoría

2. **Variables de Entorno:**
   - Usa variables para baseUrl, token, IDs
   - Automatiza la extracción del token

3. **Verificación:**
   - Verifica códigos de estado
   - Verifica estructura de respuesta
   - Verifica que la auditoría se registre

4. **Casos Negativos:**
   - Probar sin token
   - Probar con token expirado
   - Probar sin permisos
   - Probar con datos inválidos

---

## Ejemplos con cURL

### Login
```bash
curl -X POST https://localhost:5001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john_doe","password":"SecureP@ss123"}' \
  -k
```

### Crear Contenido
```bash
curl -X POST https://localhost:5001/api/content \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"title":"Test","body":"Content","tags":["test"]}' \
  -k
```

### Ver Auditoría
```bash
curl -X GET https://localhost:5001/api/audit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -k
```

---

## Automatización con Scripts

### Postman Pre-request Script

```javascript
// Verificar si hay token
if (!pm.environment.get("token")) {
    console.log("No token found, please login first");
}
```

### Postman Test Script

```javascript
// Verificar código de estado
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

// Verificar estructura
pm.test("Response has token", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('token');
});

// Guardar token
if (pm.response.code === 200 && pm.response.json().token) {
    pm.environment.set("token", pm.response.json().token);
}
```
