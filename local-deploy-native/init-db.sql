-- Cert Tracker schema for native PostgreSQL install
-- Applied by 2-init-db.ps1 to database "certtracker"

-- ============================================================
-- Roles for PostgREST
-- ============================================================
DO $$ BEGIN
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
  CREATE ROLE anon NOLOGIN;
END IF;
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
  CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'authpass_change_me';
END IF;
END $$;

GRANT anon TO authenticator;

-- ============================================================
-- Table: certificates
-- ============================================================
CREATE TABLE IF NOT EXISTS public.certificates (
id            TEXT PRIMARY KEY,
dept          TEXT NOT NULL DEFAULT 'admin',
lastname      TEXT NOT NULL DEFAULT '',
firstname     TEXT NOT NULL DEFAULT '',
middlename    TEXT DEFAULT '',
position      TEXT DEFAULT '',
treasury      BOOLEAN DEFAULT FALSE,
purposes      JSONB DEFAULT '[]'::jsonb,
expiry        DATE,
old_expiry    DATE,
dekret        BOOLEAN DEFAULT FALSE,
scan_url      TEXT,
scan_name     TEXT,
application_url  TEXT,
application_name TEXT,
created_at    TIMESTAMPTZ DEFAULT NOW(),
updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cert_dept ON public.certificates(dept);
CREATE INDEX IF NOT EXISTS idx_cert_lastname ON public.certificates(lastname);
CREATE INDEX IF NOT EXISTS idx_cert_expiry ON public.certificates(expiry);

-- ============================================================
-- Table: users
-- ============================================================
CREATE TABLE IF NOT EXISTS public.users (
id          TEXT PRIMARY KEY,
login       TEXT UNIQUE NOT NULL,
name        TEXT NOT NULL DEFAULT '',
pass_hash   TEXT NOT NULL,
role        TEXT NOT NULL DEFAULT 'viewer',
created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_login ON public.users(login);

-- Insert default admin if no users exist (pass: cert2026, sha256 hash)
INSERT INTO public.users (id, login, name, pass_hash, role)
SELECT 'u-admin', 'admin', 'Администратор',
     '8f4c6c7e8e2c5a6f9d3b1e7a8c5d4b9e6f3a2c1b8d7e5f4a3c2b1d9e8f6a5c4b',
     'admin'
WHERE NOT EXISTS (SELECT 1 FROM public.users);

-- ============================================================
-- Table: audit_log
-- ============================================================
CREATE TABLE IF NOT EXISTS public.audit_log (
id          BIGSERIAL PRIMARY KEY,
actor_id    TEXT,
actor_name  TEXT,
action      TEXT NOT NULL,
entity_type TEXT NOT NULL,
entity_id   TEXT,
summary     TEXT,
diff        JSONB,
created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_created ON public.audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON public.audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON public.audit_log(action);

-- ============================================================
-- Table: purposes
-- ============================================================
CREATE TABLE IF NOT EXISTS public.purposes (
id          TEXT PRIMARY KEY,
name        TEXT NOT NULL,
description TEXT DEFAULT '',
documents   JSONB DEFAULT '[]'::jsonb,
contacts    TEXT DEFAULT '',
created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- "Storage" emulation — простая таблица для метаданных файлов
-- (сами файлы лежат в C:\certtracker\files\, nginx их раздаёт)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.files (
id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
bucket      TEXT NOT NULL DEFAULT 'cert-files',
path        TEXT NOT NULL,
filename    TEXT NOT NULL,
size        BIGINT,
mime_type   TEXT,
uploaded_by TEXT,
created_at  TIMESTAMPTZ DEFAULT NOW(),
UNIQUE(bucket, path)
);

-- ============================================================
-- Grants
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cert_updated_at ON public.certificates;
CREATE TRIGGER trg_cert_updated_at BEFORE UPDATE ON public.certificates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
