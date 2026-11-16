# Helpdesk Schema Repair — LU 2.4 Assignment

## What This Is

You are a backend engineer on the Helpdesk team. A colleague wrote the first draft of the PostgreSQL schema in `migrations/001_initial_schema.sql`. It has **intentional errors** — wrong column types, missing constraints, wrong ON DELETE behaviour, and a rejected table shape that should have never been there.

Your job: **fix the schema so it correctly implements the ER diagram** from the assignment question. The ER diagram is the source of truth. The schema must match it exactly.

When you're done, all 36 pgTAP tests must pass.

---

## Prerequisites

Make sure you have the following installed before starting:

| Tool | Why | Check |
|------|-----|-------|
| PostgreSQL (v13+) | Runs the test database | `psql --version` |
| pgTAP | Test framework for schema validation | `pg_prove --version` |
| pg_prove | pgTAP test runner | comes with pgTAP |
| Node.js + npm | Runs the helper scripts | `node --version` |

### Installing pgTAP

**macOS (Homebrew):**
```bash
brew install pgtap
```

**Ubuntu / Debian:**
```bash
sudo apt-get install postgresql-15-pgtap
# replace 15 with your postgres version
```

**Windows (via pgxn):**
```bash
pgxn install pgtap
```

After installing, enable it in your database:
```sql
CREATE EXTENSION IF NOT EXISTS pgtap;
```

---

## Setup

### Step 1: Clone or fork the repo

```bash
git clone <repo-url>
cd helpdesk-schema-repair
```

### Step 2: Make sure PostgreSQL is running

```bash
# macOS (Homebrew)
brew services start postgresql

# Ubuntu
sudo service postgresql start

# Docker (if you prefer)
docker run --name helpdesk-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15
```

### Step 3: Create the test database and apply the schema

```bash
npm run db:reset
```

This command does three things in sequence:
1. Drops the `helpdesk_test` database if it exists
2. Creates a fresh `helpdesk_test` database
3. Applies `migrations/001_initial_schema.sql` to it

> ⚠️ If you see a "role does not exist" error, your PostgreSQL user might need to be set. Run `psql -U postgres` first and make sure you can connect. Then update the `db:reset` script in `package.json` to add `-U postgres` to each psql command.

### Step 4: Run the tests

```bash
npm test
```

The first time you run this, **most tests will fail**. That's expected — the schema is broken. Your job is to fix it until all 36 pass.

---

## What the Tests Check

The 36 pgTAP tests verify:

| Category | Tests | What they check |
|----------|-------|-----------------|
| Table existence | 6 | All 6 tables exist (including the 2 you need to add) |
| Column types | 16 | UUIDs are UUID not INTEGER, timestamps are TIMESTAMPTZ not TIMESTAMP, booleans are BOOLEAN not TEXT |
| NOT NULL | 11 | Required fields are actually marked NOT NULL |
| Nullable | 3 | Optional fields are correctly nullable |
| Column absence | 1 | The rejected `tags TEXT[]` column is gone |
| UNIQUE | 1 | `agents.email` is UNIQUE |

---

## The File to Fix

**Only edit this file:**

```
migrations/001_initial_schema.sql
```

Every broken line has a `-- wrong:` comment explaining what the problem is. Read each comment carefully.

---

## Hints

Work table by table. Don't try to fix everything at once.

**Hint 1 — Types:**
The ERD uses conceptual types. Translate them:
- `uuid` → `UUID`
- `string` → `TEXT` (not VARCHAR)
- `text` → `TEXT`
- `boolean` → `BOOLEAN` (not TEXT)
- `timestamp` → `TIMESTAMPTZ` (not TIMESTAMP — timezone matters in production)

**Hint 2 — Primary Keys:**
Every `SERIAL PRIMARY KEY` should be `UUID PRIMARY KEY DEFAULT gen_random_uuid()`. Check if you need to enable the `pgcrypto` extension first.

**Hint 3 — NOT NULL:**
If the ERD shows a field without `"nullable"` in quotes, it is required. Add `NOT NULL`. Go through every field in every entity in the ERD.

**Hint 4 — CHECK constraints:**
If the ERD attribute note shows pipe-separated values like `"starter|pro|enterprise"`, that means a CHECK constraint with exactly those allowed values. Do not use an ENUM type — use `TEXT NOT NULL CHECK (column IN (...))`.

**Hint 5 — Foreign Keys:**
All FK columns in the broken schema are `INTEGER`. They should all be `UUID`. Also: every FK needs an explicit `ON DELETE` clause. Look at the assignment question for the correct ON DELETE behaviour per FK (the table is provided there).

**Hint 6 — The Rejected Shape:**
There's an `ALTER TABLE` at the bottom of the broken schema adding `tags TEXT[]` to tickets. This is the wrong design. Remove that line entirely. Then add two new tables: `tags` and `ticket_tags`. Their columns are in the ER diagram.

**Hint 7 — Timestamps:**
All `created_at` columns should have `NOT NULL DEFAULT NOW()`. All nullable timestamp columns (`resolved_at`, `deactivated_at`) should have no DEFAULT and no NOT NULL.

---

## Workflow

The recommended loop while fixing:

```bash
# 1. Edit the schema
nano migrations/001_initial_schema.sql   # or use your editor

# 2. Reset the database (re-applies the schema from scratch)
npm run db:reset

# 3. Run the tests and see how many pass
npm test

# 4. Repeat until all 36 pass
```

Each time you run `db:reset`, the database is wiped and recreated from your current schema file. This means each run is a clean slate — no leftover state.

---

## Common Errors

**`ERROR: type "uuid" does not exist`**
→ Add `CREATE EXTENSION IF NOT EXISTS "pgcrypto";` at the top of your SQL file.

**`ERROR: function gen_random_uuid() does not exist`**
→ Same fix — pgcrypto extension is not enabled.

**`ERROR: column "tags" of relation "tickets" does not exist` (when running tests)**
→ You still have the `ALTER TABLE tickets ADD COLUMN tags TEXT[]` line. Remove it.

**`ERROR: there is no unique constraint matching given keys for referenced table`**
→ A FK references a column that is not a primary key or unique. Check your FK definitions.

**`pg_prove: command not found`**
→ pgTAP is not installed or not on your PATH. See prerequisites above.

**`psql: error: connection to server failed`**
→ PostgreSQL is not running. Start it with `brew services start postgresql` (macOS) or `sudo service postgresql start` (Linux).

---

## Submission

Once all 36 tests pass:

1. Commit your changes to a branch called `schema-repair`:
```bash
git checkout -b schema-repair
git add migrations/001_initial_schema.sql README.md
git commit -m "fix: repair helpdesk schema to match ERD"
```

2. Update `README.md` (this file) with exactly **3 ERD-to-schema decisions** and **1 rejected table shape** using this format:

```markdown
## ERD-to-Schema Decisions

### Decision 1: [Column type decision]
ERD said: ...
Schema decided: ...
Reason: ...

### Decision 2: [ON DELETE decision]
ERD said: ...
Schema decided: ...
Reason: ...

### Decision 3: [Default value decision]
ERD said: ...
Schema decided: ...
Reason: ...

## Rejected Table Shape

### Shape: [name what you removed or rejected]
What it was: ...
Why rejected: ...
What would break: ...
```

3. Push and open a PR:
```bash
git push origin schema-repair
```

4. In the PR description, paste your `npm test` output showing all 36 tests passing.

---

## What You May Not Do

- Change the ER diagram (it is the source of truth)
- Add columns that don't exist in the ER diagram
- Skip `ON DELETE` on any FK — every FK must have an explicit `ON DELETE` clause
- Use `SERIAL` or `INTEGER` for any PK or FK column
- Leave the `tags TEXT[]` array column on the tickets table
- Use ENUM type instead of TEXT + CHECK

---

## Project Structure

```
helpdesk-schema-repair/
├── migrations/
│   └── 001_initial_schema.sql   ← the broken schema — only file you edit
├── tests/
│   └── schema.test.sql          ← 36 pgTAP tests — do not edit
├── README.md                    ← this file — update with your decisions
└── package.json                 ← npm scripts — do not edit
```

---

# My Submission — Schema Repair (branch `schema-repair`)

## ERD-to-Schema Decisions

### Decision 1: Column type decision — `tickets.priority` and `tickets.status`
ERD said: `priority "low|medium|high|urgent"` and `status "open|pending|resolved|closed"` — pipe-separated lists inside a `string` attribute.
Schema decided: `TEXT NOT NULL CHECK (priority IN ('low','medium','high','urgent'))` and `TEXT NOT NULL CHECK (status IN ('open','pending','resolved','closed'))`. No PostgreSQL `ENUM` type, and no `VARCHAR(n)`.
Reason: the ERD states the allowed values but not how to enforce them, and it never states a length. A CHECK list is one rule on the table, so adding a status next year (say `reopened`) is a single statement, while removing a value from an `ENUM` type is awkward and the type is a separate object to manage. `TEXT` is used rather than `VARCHAR(n)` because in PostgreSQL the two perform the same and a limit here would be an invented rule the ERD never asked for. The rejected `priority` values are now impossible: a ticket cannot be filed as `critical`, because the database refuses the row, not because application code remembers to check.

### Decision 2: ON DELETE decision — `tickets.assignee_id`
ERD said: `uuid assignee_id FK "nullable"` and the relationship is `Agent o|--o{ Ticket : "assigned to"` — zero or one agent per ticket, and the attribute is explicitly nullable.
Schema decided: `assignee_id UUID REFERENCES agents(id) ON DELETE SET NULL`. The other agent link on the same table, `created_by`, takes `ON DELETE RESTRICT`.
Reason: the ERD shows the link is optional, but it says nothing about what happens when that agent row is deleted. Two different facts live on those two columns. `created_by` is an audit record — the ticket must always be able to name who filed it, so the delete is refused and history stays correct. `assignee_id` is only today's owner, so when an agent leaves, the ticket should survive and become unassigned rather than disappear or block the delete. `CASCADE` would have been wrong on both: deleting an agent must never delete the tickets they filed or were working on. `SET NULL` also requires the column to stay nullable, which is why `NOT NULL` was not added here.

### Decision 3: Default value decision — `created_at` on every table
ERD said: `timestamp created_at` on all six entities. It records that the row has a creation time, and nothing about who fills it in.
Schema decided: `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, plus `DEFAULT FALSE` on `comments.internal`, `DEFAULT 'open'` on `tickets.status`, and `DEFAULT NOW()` on `ticket_tags.added_at`. `resolved_at` and `deactivated_at` get no default, because their empty state is meaningful: NULL means "not resolved yet" and "still active".
Reason: a default that lives only in application code is not a rule. A migration script, a backfill, a manual `INSERT` in a console, or a second service would all skip it and write NULL or the wrong value. `DEFAULT NOW()` puts the timestamp on the server clock, so every row has one moment of truth no matter which path created it, and `TIMESTAMPTZ` stores the exact moment rather than a wall-clock reading that reads differently in each time zone. Nullable columns are left without a default on purpose: `DEFAULT NOW()` on `resolved_at` would claim every ticket was resolved the instant it was created.

## Rejected Table Shape

### Shape: an array of tags on the ticket — `tickets.tags TEXT[]`
What it was: the starter schema kept tags as a text array column on `tickets`, so one ticket row held its tag names directly, for example `{billing,vip}`. The ERD instead models `Tag` and `TicketTag` as entities of their own. I removed the `ALTER TABLE tickets ADD COLUMN tags TEXT[]` line entirely and created `tags` (`id`, `org_id`, `name`, `color_hex`) and `ticket_tags` (`id`, `ticket_id`, `tag_id`, `added_by`, `added_at`).
Why rejected: in the array, a tag has no identity of its own. There is no row to rename, so renaming "billing" to "invoices" means rewriting every ticket that mentions it, and nothing checks spelling — `billing`, `Billing` and `billling` become three different tags. The array also cannot carry the attributes the ERD gives a tag: no `color_hex`, no owning `org_id`, and no record of which agent applied it or when, so the audit trail in `ticket_tags.added_by` and `added_at` is simply lost.
What would break: every tag-shaped query becomes a scan and a string comparison instead of an indexed join — "all tickets tagged billing in this org" reads every ticket row and parses an array. Deleting an organization could not cascade to its tags, because the array has no `org_id`. Two agents tagging the same ticket concurrently could produce duplicates with no constraint to stop them, while the join table's `UNIQUE (ticket_id, tag_id)` refuses a second identical application. And the array cannot enforce that a ticket's tag belongs to the same organization as the ticket, which `tags.org_id` makes checkable.

## Additional integrity rules added (no columns invented)

- `UNIQUE (org_id, name)` on `tags` — one tag name per organization, which is what stops the spelling drift the array allowed.
- `UNIQUE (ticket_id, tag_id)` on `ticket_tags` — the same tag cannot be applied to the same ticket twice.
- `UNIQUE` on `agents.email` — the ERD does not mark it, but an email identifies an account, and the assignment requires it.

## Test Output

36/36 pgTAP assertions pass:

```
1..36
ok 1 - organizations table exists
ok 2 - agents table exists
ok 3 - tickets table exists
ok 4 - comments table exists
ok 5 - tags table exists
ok 6 - ticket_tags table exists
ok 7 - organizations.id is UUID
ok 8 - agents.id is UUID
ok 9 - tickets.id is UUID
ok 10 - comments.id is UUID
ok 11 - tags.id is UUID
ok 12 - ticket_tags.id is UUID
ok 13 - agents.org_id is UUID FK
ok 14 - tickets.org_id is UUID FK
ok 15 - tickets.created_by is UUID FK
ok 16 - tickets.assignee_id is UUID FK
ok 17 - organizations.created_at is TIMESTAMPTZ
ok 18 - tickets.created_at is TIMESTAMPTZ
ok 19 - comments.created_at is TIMESTAMPTZ
ok 20 - comments.internal is BOOLEAN not TEXT
ok 21 - organizations.name is NOT NULL
ok 22 - agents.name is NOT NULL
ok 23 - agents.email is NOT NULL
ok 24 - agents.org_id is NOT NULL
ok 25 - tickets.subject is NOT NULL
ok 26 - tickets.status is NOT NULL
ok 27 - tickets.org_id is NOT NULL
ok 28 - tickets.created_by is NOT NULL
ok 29 - comments.body is NOT NULL
ok 30 - comments.ticket_id is NOT NULL
ok 31 - comments.author_id is NOT NULL
ok 32 - tickets.assignee_id is nullable
ok 33 - tickets.resolved_at is nullable
ok 34 - agents.deactivated_at is nullable
ok 35 - tickets.tags array column must be removed
ok 36 - agents.email is UNIQUE
1..36
All tests successful.
```

Behaviour checked by hand on top of the tests: a `plan` of `free` is refused by the CHECK, a duplicate `agents.email` is refused by UNIQUE, deleting an agent who filed a ticket is refused by RESTRICT, deleting the assignee leaves the ticket with `assignee_id` NULL, deleting a tag removes its `ticket_tags` rows, deleting a ticket removes its comments, and an inserted ticket with no status arrives as `open`.
