-- Helpdesk Schema — repaired to match the ER diagram (source of truth)
-- Reference: the ER diagram in the assignment question
--
-- Conventions used throughout:
--   uuid      -> UUID PRIMARY KEY DEFAULT gen_random_uuid()
--   string    -> TEXT            (VARCHAR only when a length limit is a real rule)
--   timestamp -> TIMESTAMPTZ     (exact moment, not a wall-clock reading)
--   boolean   -> BOOLEAN         (never TEXT 'true'/'false')
--   "a|b|c"   -> TEXT NOT NULL CHECK (col IN ('a','b','c'))
--   every FK  -> explicit ON DELETE action

-- Setup: enable UUID generation (gen_random_uuid() is core from PG13, pgcrypto covers older servers)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Organizations
CREATE TABLE organizations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  plan       TEXT NOT NULL CHECK (plan IN ('starter', 'pro', 'enterprise')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Agents
CREATE TABLE agents (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  email          TEXT NOT NULL UNIQUE,
  role           TEXT NOT NULL CHECK (role IN ('agent', 'supervisor', 'admin')),
  -- An organization cannot be deleted while it still has agents.
  org_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deactivated_at TIMESTAMPTZ   -- NULL means the agent is still active
);

-- Tickets
CREATE TABLE tickets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject     TEXT NOT NULL,
  body        TEXT,            -- optional by the ERD
  priority    TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  status      TEXT NOT NULL DEFAULT 'open'
              CHECK (status IN ('open', 'pending', 'resolved', 'closed')),
  -- An organization cannot be deleted while it still has tickets.
  org_id      UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  -- Audit record: who filed the ticket must survive.
  created_by  UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
  -- An assignee is only today's owner: the ticket survives, unassigned.
  assignee_id UUID REFERENCES agents(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ      -- stays NULL until the ticket is resolved
);

-- Comments
CREATE TABLE comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Comments mean nothing without their ticket, so they die with it.
  ticket_id  UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  -- Audit record: who wrote the comment must survive.
  author_id  UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
  body       TEXT NOT NULL,
  internal   BOOLEAN NOT NULL DEFAULT FALSE,  -- TRUE = visible to agents only
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tags (replaces the rejected tickets.tags TEXT[] array shape)
CREATE TABLE tags (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Tags are owned by the organization, so they go with it.
  org_id    UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  color_hex TEXT NOT NULL,
  -- A tag name exists once per organization, which the array column could never enforce.
  UNIQUE (org_id, name)
);

-- TicketTag (resolves the many-to-many between tickets and tags)
CREATE TABLE ticket_tags (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Tag associations die with the ticket.
  ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
  -- Tag associations die if the tag itself is deleted.
  tag_id    UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  -- Audit record: who applied the tag must survive.
  added_by  UUID NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
  added_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- The same tag cannot be applied to the same ticket twice.
  UNIQUE (ticket_id, tag_id)
);
