-- Esomoire Genesis Control Plane
-- Migration: 0001_genesis_control_plane.sql
-- Purpose: canonical Postgres schema for registry, licensing, evidence, payments, approvals, tasks, and telemetry references.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Enum-like constrained values are kept as text with CHECK constraints initially.
-- This keeps the migration portable across Supabase, Neon, Railway, Cloud SQL, and self-hosted Postgres.
-- -----------------------------------------------------------------------------

create table if not exists entities (
    entity_id uuid primary key default gen_random_uuid(),
    entity_name text not null,
    entity_type text not null check (entity_type in ('person', 'organization', 'arc', 'product', 'service', 'node', 'other')),
    jurisdiction text,
    status text not null default 'active' check (status in ('draft', 'active', 'suspended', 'archived')),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists people (
    person_id uuid primary key default gen_random_uuid(),
    entity_id uuid references entities(entity_id) on delete set null,
    display_name text not null,
    email text,
    phone text,
    classification text check (classification in ('employee', 'contractor', 'vendor', 'intern', 'member', 'volunteer', 'partner', 'advisor', 'beneficiary', 'other')),
    digitalme_id text unique,
    status text not null default 'draft' check (status in ('draft', 'verified', 'active', 'suspended', 'archived')),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists organizations (
    organization_id uuid primary key default gen_random_uuid(),
    entity_id uuid references entities(entity_id) on delete set null,
    legal_name text not null,
    trade_name text,
    gstin text,
    cin_or_llpin text,
    jurisdiction text,
    status text not null default 'draft' check (status in ('draft', 'verified', 'active', 'suspended', 'archived')),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists locations (
    location_id uuid primary key default gen_random_uuid(),
    location_name text not null,
    location_type text not null default 'site',
    address_text text,
    city text,
    state text,
    country text default 'India',
    latitude numeric(10, 7),
    longitude numeric(10, 7),
    status text not null default 'draft' check (status in ('draft', 'active', 'suspended', 'archived')),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists arcs (
    arc_id uuid primary key default gen_random_uuid(),
    entity_id uuid references entities(entity_id) on delete set null,
    arc_name text not null,
    arc_type text not null check (arc_type in ('factory', 'retail', 'data_center', 'registry', 'recovery', 'logistics', 'governance', 'other')),
    location_id uuid references locations(location_id) on delete set null,
    operating_entity_id uuid references entities(entity_id) on delete set null,
    status text not null default 'draft' check (status in ('draft', 'active', 'paused', 'closed', 'archived')),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists arc_members (
    arc_member_id uuid primary key default gen_random_uuid(),
    arc_id uuid not null references arcs(arc_id) on delete cascade,
    person_id uuid references people(person_id) on delete set null,
    organization_id uuid references organizations(organization_id) on delete set null,
    role text not null,
    classification text not null check (classification in ('employee', 'contractor', 'vendor', 'intern', 'member', 'volunteer', 'partner', 'advisor', 'beneficiary', 'other')),
    onboarding_status text not null default 'pending' check (onboarding_status in ('pending', 'invited', 'verified', 'active', 'rejected', 'offboarded')),
    joined_at timestamptz,
    exited_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (person_id is not null or organization_id is not null)
);

create table if not exists products (
    product_id uuid primary key default gen_random_uuid(),
    entity_id uuid references entities(entity_id) on delete set null,
    product_name text not null,
    product_family text,
    owner_entity_id uuid references entities(entity_id) on delete set null,
    passport_id text unique,
    status text not null default 'draft' check (status in ('draft', 'active', 'suspended', 'archived')),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists licenses (
    license_id uuid primary key default gen_random_uuid(),
    license_type text not null,
    subject_entity_id uuid references entities(entity_id) on delete set null,
    subject_ref text,
    issuer_node text not null,
    scope jsonb not null default '{}'::jsonb,
    status text not null default 'draft' check (status in ('draft', 'issued', 'active', 'suspended', 'revoked', 'expired')),
    issued_at timestamptz,
    expires_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists evidence_records (
    evidence_id uuid primary key default gen_random_uuid(),
    event_type text not null,
    subject_entity_id uuid references entities(entity_id) on delete set null,
    subject_ref text,
    source_service text not null,
    object_store_uri text,
    content_hash text,
    trace_id text,
    span_id text,
    recorded_at timestamptz not null default now(),
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists payments (
    payment_id uuid primary key default gen_random_uuid(),
    payer_entity_id uuid references entities(entity_id) on delete set null,
    payee_entity_id uuid references entities(entity_id) on delete set null,
    amount numeric(18, 2) not null check (amount >= 0),
    currency text not null default 'INR',
    payment_type text not null check (payment_type in ('setup_fee', 'subscription', 'utility', 'license_fee', 'success_fee', 'recovery', 'settlement', 'other')),
    status text not null default 'draft' check (status in ('draft', 'authorized', 'captured', 'settled', 'failed', 'refunded', 'cancelled')),
    settlement_reference text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists tasks (
    task_id uuid primary key default gen_random_uuid(),
    title text not null,
    description text,
    assigned_person_id uuid references people(person_id) on delete set null,
    assigned_entity_id uuid references entities(entity_id) on delete set null,
    arc_id uuid references arcs(arc_id) on delete set null,
    priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'critical')),
    status text not null default 'open' check (status in ('open', 'in_progress', 'blocked', 'done', 'cancelled')),
    due_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists approvals (
    approval_id uuid primary key default gen_random_uuid(),
    approval_type text not null,
    subject_entity_id uuid references entities(entity_id) on delete set null,
    subject_ref text,
    requested_by_person_id uuid references people(person_id) on delete set null,
    approver_person_id uuid references people(person_id) on delete set null,
    status text not null default 'requested' check (status in ('requested', 'under_review', 'approved', 'rejected', 'cancelled')),
    decision_at timestamptz,
    decision_note text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists telemetry_events (
    event_id uuid primary key default gen_random_uuid(),
    service_name text not null,
    event_name text not null,
    entity_type text,
    entity_id uuid references entities(entity_id) on delete set null,
    authority_node text,
    risk_level text not null default 'low' check (risk_level in ('low', 'medium', 'high', 'critical')),
    trace_id text,
    span_id text,
    occurred_at timestamptz not null default now(),
    attributes jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_entities_type_status on entities(entity_type, status);
create index if not exists idx_people_email on people(email);
create index if not exists idx_people_digitalme_id on people(digitalme_id);
create index if not exists idx_organizations_gstin on organizations(gstin);
create index if not exists idx_arcs_location on arcs(location_id);
create index if not exists idx_arc_members_arc on arc_members(arc_id);
create index if not exists idx_products_passport_id on products(passport_id);
create index if not exists idx_licenses_subject_status on licenses(subject_entity_id, status);
create index if not exists idx_evidence_subject on evidence_records(subject_entity_id, recorded_at desc);
create index if not exists idx_payments_status on payments(status, created_at desc);
create index if not exists idx_tasks_status_due on tasks(status, due_at);
create index if not exists idx_approvals_status on approvals(status, created_at desc);
create index if not exists idx_telemetry_events_service_time on telemetry_events(service_name, occurred_at desc);
create index if not exists idx_telemetry_events_risk on telemetry_events(risk_level, occurred_at desc);

create or replace function set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists trg_entities_updated_at on entities;
create trigger trg_entities_updated_at before update on entities for each row execute function set_updated_at();

drop trigger if exists trg_people_updated_at on people;
create trigger trg_people_updated_at before update on people for each row execute function set_updated_at();

drop trigger if exists trg_organizations_updated_at on organizations;
create trigger trg_organizations_updated_at before update on organizations for each row execute function set_updated_at();

drop trigger if exists trg_locations_updated_at on locations;
create trigger trg_locations_updated_at before update on locations for each row execute function set_updated_at();

drop trigger if exists trg_arcs_updated_at on arcs;
create trigger trg_arcs_updated_at before update on arcs for each row execute function set_updated_at();

drop trigger if exists trg_arc_members_updated_at on arc_members;
create trigger trg_arc_members_updated_at before update on arc_members for each row execute function set_updated_at();

drop trigger if exists trg_products_updated_at on products;
create trigger trg_products_updated_at before update on products for each row execute function set_updated_at();

drop trigger if exists trg_licenses_updated_at on licenses;
create trigger trg_licenses_updated_at before update on licenses for each row execute function set_updated_at();

drop trigger if exists trg_payments_updated_at on payments;
create trigger trg_payments_updated_at before update on payments for each row execute function set_updated_at();

drop trigger if exists trg_tasks_updated_at on tasks;
create trigger trg_tasks_updated_at before update on tasks for each row execute function set_updated_at();

drop trigger if exists trg_approvals_updated_at on approvals;
create trigger trg_approvals_updated_at before update on approvals for each row execute function set_updated_at();

-- Seed the first bootstrap entity and node record.
insert into entities (entity_name, entity_type, jurisdiction, status, metadata)
values (
    'Esomoire Genesis Bootstrap Node',
    'node',
    'India',
    'active',
    '{"service_namespace":"esomoire.genesis","manifest":"configs/esomoire/genesis-control-plane.yaml"}'::jsonb
)
on conflict do nothing;
