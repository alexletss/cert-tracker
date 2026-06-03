-- Initialize Cert Tracker database schema
-- This runs automatically on first Postgres container start

-- Roles needed by PostgREST
DO $$ BEGIN
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
  CREATE ROLE anon NOLOGIN;
END IF;
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
  CREATE ROLE authenticated NOLOGIN;
END IF;
IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
  CREATE ROLE service_role NOLOGIN BYPASSRLS;
END IF;
END $$;

GRANT anon, authenticated, service_role TO postgres;

-- ============================================================
-- Table: certificates (main employee table)
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
-- Table: users (auth)
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
-- Storage bucket setup (mimics Supabase Storage)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
id    TEXT PRIMARY KEY,
name  TEXT UNIQUE NOT NULL,
owner TEXT,
public BOOLEAN DEFAULT FALSE,
created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS storage.objects (
id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
bucket_id   TEXT NOT NULL REFERENCES storage.buckets(id),
name        TEXT NOT NULL,
owner       TEXT,
metadata    JSONB,
created_at  TIMESTAMPTZ DEFAULT NOW(),
updated_at  TIMESTAMPTZ DEFAULT NOW(),
UNIQUE(bucket_id, name)
);

INSERT INTO storage.buckets (id, name, public)
VALUES ('cert-files', 'cert-files', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Realtime schema
-- ============================================================
CREATE SCHEMA IF NOT EXISTS _realtime;
ALTER PUBLICATION supabase_realtime ADD TABLE public.certificates, public.users, public.audit_log, public.purposes;
-- Note: if publication doesn't exist yet, ignore the error; realtime container will create it.

-- ============================================================
-- Grants for PostgREST roles
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- Auto-update updated_at on certificates
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cert_updated_at ON public.certificates;
CREATE TRIGGER trg_cert_updated_at BEFORE UPDATE ON public.certificates
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
