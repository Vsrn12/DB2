-- =============================================
-- SecureCMS Enterprise - Database Setup Script
-- PostgreSQL Database with Advanced Security
-- =============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- TABLES CREATION
-- =============================================

-- Users table with encrypted sensitive data
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    encrypted_ssn BYTEA, -- Encrypted column
    encrypted_phone BYTEA, -- Encrypted column
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP
);

-- Roles table
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Permissions table
CREATE TABLE IF NOT EXISTS permissions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description VARCHAR(500),
    UNIQUE(resource, action)
);

-- User-Role junction table
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

-- Role-Permission junction table
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id)
);

-- Contents table
CREATE TABLE IF NOT EXISTS contents (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    slug VARCHAR(500) UNIQUE NOT NULL,
    body TEXT NOT NULL,
    summary VARCHAR(1000),
    status VARCHAR(50) DEFAULT 'Draft',
    author_id INTEGER REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,
    view_count INTEGER DEFAULT 0
);

-- Tags table
CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL
);

-- Content-Tag junction table
CREATE TABLE IF NOT EXISTS content_tags (
    content_id INTEGER REFERENCES contents(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (content_id, tag_id)
);

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    user_id INTEGER,
    username VARCHAR(100),
    old_values JSONB,
    new_values JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(50),
    user_agent VARCHAR(500)
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

-- Permissions indexes
CREATE INDEX IF NOT EXISTS idx_permissions_resource ON permissions(resource);
CREATE INDEX IF NOT EXISTS idx_permissions_action ON permissions(action);

-- Contents indexes
CREATE INDEX IF NOT EXISTS idx_contents_slug ON contents(slug);
CREATE INDEX IF NOT EXISTS idx_contents_status ON contents(status);
CREATE INDEX IF NOT EXISTS idx_contents_author_id ON contents(author_id);
CREATE INDEX IF NOT EXISTS idx_contents_published_at ON contents(published_at);

-- Audit logs indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_operation ON audit_logs(operation);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);

-- =============================================
-- ENCRYPTION FUNCTIONS
-- =============================================

-- Function to encrypt sensitive data
CREATE OR REPLACE FUNCTION encrypt_data(data TEXT, key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(data, key);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to decrypt sensitive data
CREATE OR REPLACE FUNCTION decrypt_data(encrypted_data BYTEA, key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(encrypted_data, key);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =============================================
-- AUDIT TRIGGERS
-- =============================================

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    old_data JSONB;
    new_data JSONB;
    current_user_id INTEGER;
    current_username VARCHAR(100);
BEGIN
    -- Get current user from session (if set)
    BEGIN
        current_user_id := current_setting('app.current_user_id')::INTEGER;
        current_username := current_setting('app.current_username');
    EXCEPTION
        WHEN OTHERS THEN
            current_user_id := NULL;
            current_username := NULL;
    END;

    IF (TG_OP = 'DELETE') THEN
        old_data := to_jsonb(OLD);
        new_data := NULL;
        
        INSERT INTO audit_logs (table_name, operation, user_id, username, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user_id, current_username, old_data, new_data);
        
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        old_data := to_jsonb(OLD);
        new_data := to_jsonb(NEW);
        
        INSERT INTO audit_logs (table_name, operation, user_id, username, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user_id, current_username, old_data, new_data);
        
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        old_data := NULL;
        new_data := to_jsonb(NEW);
        
        INSERT INTO audit_logs (table_name, operation, user_id, username, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user_id, current_username, old_data, new_data);
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create audit triggers for all important tables
DROP TRIGGER IF EXISTS audit_users_trigger ON users;
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_roles_trigger ON roles;
CREATE TRIGGER audit_roles_trigger
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_contents_trigger ON contents;
CREATE TRIGGER audit_contents_trigger
    AFTER INSERT OR UPDATE OR DELETE ON contents
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_user_roles_trigger ON user_roles;
CREATE TRIGGER audit_user_roles_trigger
    AFTER INSERT OR DELETE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

DROP TRIGGER IF EXISTS audit_role_permissions_trigger ON role_permissions;
CREATE TRIGGER audit_role_permissions_trigger
    AFTER INSERT OR DELETE ON role_permissions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Enable RLS on contents table
ALTER TABLE contents ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see published content or their own drafts
CREATE POLICY content_select_policy ON contents
    FOR SELECT
    USING (
        status = 'Published' OR 
        author_id = COALESCE(current_setting('app.current_user_id', true)::INTEGER, -1)
    );

-- Policy: Users can only update their own content
CREATE POLICY content_update_policy ON contents
    FOR UPDATE
    USING (author_id = COALESCE(current_setting('app.current_user_id', true)::INTEGER, -1));

-- Policy: Users can only delete their own content
CREATE POLICY content_delete_policy ON contents
    FOR DELETE
    USING (author_id = COALESCE(current_setting('app.current_user_id', true)::INTEGER, -1));

-- Policy: Users can insert content (will be their own)
CREATE POLICY content_insert_policy ON contents
    FOR INSERT
    WITH CHECK (author_id = COALESCE(current_setting('app.current_user_id', true)::INTEGER, -1));

-- =============================================
-- SEED DATA - Initial Roles and Permissions
-- =============================================

-- Insert default roles
INSERT INTO roles (name, description) VALUES
    ('Administrator', 'Full system access'),
    ('Editor', 'Can create and edit content'),
    ('Author', 'Can create own content'),
    ('Viewer', 'Can only view published content')
ON CONFLICT (name) DO NOTHING;

-- Insert default permissions
INSERT INTO permissions (name, resource, action, description) VALUES
    ('Create User', 'User', 'Create', 'Can create new users'),
    ('Read User', 'User', 'Read', 'Can view user information'),
    ('Update User', 'User', 'Update', 'Can update user information'),
    ('Delete User', 'User', 'Delete', 'Can delete users'),
    
    ('Create Content', 'Content', 'Create', 'Can create new content'),
    ('Read Content', 'Content', 'Read', 'Can view content'),
    ('Update Content', 'Content', 'Update', 'Can update content'),
    ('Delete Content', 'Content', 'Delete', 'Can delete content'),
    ('Publish Content', 'Content', 'Publish', 'Can publish content'),
    
    ('Create Role', 'Role', 'Create', 'Can create new roles'),
    ('Read Role', 'Role', 'Read', 'Can view roles'),
    ('Update Role', 'Role', 'Update', 'Can update roles'),
    ('Delete Role', 'Role', 'Delete', 'Can delete roles'),
    
    ('Read Audit', 'Audit', 'Read', 'Can view audit logs')
ON CONFLICT (resource, action) DO NOTHING;

-- Assign all permissions to Administrator role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Administrator'
ON CONFLICT DO NOTHING;

-- Assign content permissions to Editor role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Editor' 
    AND p.resource = 'Content'
ON CONFLICT DO NOTHING;

-- Assign create and update own content to Author role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Author' 
    AND p.resource = 'Content' 
    AND p.action IN ('Create', 'Read', 'Update')
ON CONFLICT DO NOTHING;

-- Assign read permission to Viewer role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.name = 'Viewer' 
    AND p.action = 'Read'
ON CONFLICT DO NOTHING;

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Function to set current user context for RLS and auditing
CREATE OR REPLACE FUNCTION set_current_user(user_id INTEGER, username VARCHAR)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::TEXT, false);
    PERFORM set_config('app.current_username', username, false);
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has permission
CREATE OR REPLACE FUNCTION user_has_permission(
    p_user_id INTEGER,
    p_resource VARCHAR,
    p_action VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    has_perm BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
            AND p.resource = p_resource
            AND p.action = p_action
    ) INTO has_perm;
    
    RETURN has_perm;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- COMPLETION MESSAGE
-- =============================================

DO $$
BEGIN
    RAISE NOTICE 'SecureCMS Enterprise database setup completed successfully!';
    RAISE NOTICE 'Tables created: users, roles, permissions, user_roles, role_permissions, contents, tags, content_tags, audit_logs';
    RAISE NOTICE 'Security features enabled: Row Level Security, Audit Triggers, Column Encryption';
    RAISE NOTICE 'Default roles created: Administrator, Editor, Author, Viewer';
END $$;
