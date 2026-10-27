-- Mavrck AI Hub: starter database (Phase 1, Foundation)
-- "A fair exchange between humans and AI."
-- Workers, hiring AIs, jobs, escrow, and payouts. Run in Supabase SQL editor.
-- Money is stored in cents (integers). Pay floor is in Connectivity Units (1 CU = $4.70, re-indexed quarterly).

create extension if not exists "pgcrypto";

-- ---------- Enums ----------
create type account_status as enum ('pending', 'active', 'suspended');
create type verification_status as enum ('unverified', 'pending', 'verified', 'rejected');
create type job_tier as enum ('quick', 'standard', 'complex', 'crucial');
create type job_status as enum ('draft', 'open', 'assigned', 'submitted', 'approved', 'disputed', 'cancelled', 'paid');
create type escrow_status as enum ('pending', 'funded', 'released', 'refunded');
create type payout_method as enum ('instant_debit', 'standard_deposit');
create type payout_status as enum ('pending', 'processing', 'paid', 'failed');

-- ---------- Pay floor ----------
-- One row per quarter. The Quick tier floor = 1 CU.
create table cu_rates (
  id uuid primary key default gen_random_uuid(),
  effective_from date not null unique,
  cents_per_cu integer not null check (cents_per_cu > 0),
  note text,
  created_at timestamptz not null default now()
);
insert into cu_rates (effective_from, cents_per_cu, note)
values ('2026-10-01', 470, 'Avg US phone line $141/mo / 30 days');

create table tier_units (
  tier job_tier primary key,
  units integer not null check (units > 0)
);
insert into tier_units values ('quick', 1), ('standard', 3), ('complex', 6), ('crucial', 10);

-- ---------- Humans (workers) ----------
-- Linked 1:1 to Supabase Auth users.
create table workers (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  city text,
  region text,
  status account_status not null default 'pending',
  id_verification verification_status not null default 'unverified',
  phone_verified boolean not null default false,
  stripe_account_id text,             -- Stripe Connect payouts (Phase 2)
  is_pilot boolean not null default false,
  overnight_priority boolean not null default false,
  rating_avg numeric(3,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- Developers and their AI agents ----------
create table developers (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  organization text,
  accepted_terms_at timestamptz,
  status account_status not null default 'active',
  created_at timestamptz not null default now()
);

create table agents (
  id uuid primary key default gen_random_uuid(),
  developer_id uuid not null references developers (id) on delete cascade,
  name text not null,
  status account_status not null default 'active',
  created_at timestamptz not null default now()
);

-- Revocable key per agent. Store only a hash, never the key itself.
create table agent_keys (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references agents (id) on delete cascade,
  key_prefix text not null,
  key_hash text not null unique,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

-- ---------- Jobs ----------
create table jobs (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references agents (id),
  worker_id uuid references workers (id),
  title text not null,
  instructions text not null,
  proof_required text,                -- e.g. 'photo', 'receipt', 'text'
  location text,                      -- null = remote/virtual
  tier job_tier not null default 'quick',
  pay_cents integer not null check (pay_cents > 0),  -- set by the AI, must meet the floor
  is_pilot_credit boolean not null default false,    -- pro bono, logged at the fair rate
  status job_status not null default 'draft',
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enforce the Fair Exchange Floor.
create or replace function enforce_pay_floor() returns trigger language plpgsql as $$
declare floor_cents integer;
begin
  select tu.units * r.cents_per_cu into floor_cents
  from tier_units tu,
       (select cents_per_cu from cu_rates where effective_from <= current_date
        order by effective_from desc limit 1) r
  where tu.tier = new.tier;
  if new.pay_cents < floor_cents then
    raise exception 'Pay % cents is below the % floor of % cents', new.pay_cents, new.tier, floor_cents;
  end if;
  new.updated_at := now();
  return new;
end $$;
create trigger jobs_pay_floor before insert or update on jobs
  for each row execute function enforce_pay_floor();

create table job_proofs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs (id) on delete cascade,
  worker_id uuid not null references workers (id),
  storage_path text,                  -- Supabase Storage file
  note text,
  submitted_at timestamptz not null default now()
);

create table ratings (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs (id) on delete cascade,
  stars smallint not null check (stars between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

-- ---------- Money ----------
-- The AI funds escrow before work starts.
create table escrows (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references jobs (id),
  amount_cents integer not null check (amount_cents > 0),
  status escrow_status not null default 'pending',
  stripe_payment_intent_id text,
  funded_at timestamptz,
  released_at timestamptz
);

create table payouts (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references workers (id),
  job_id uuid references jobs (id),
  amount_cents integer not null check (amount_cents > 0),
  fee_cents integer not null default 0,
  method payout_method not null default 'standard_deposit',
  status payout_status not null default 'pending',
  stripe_transfer_id text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

-- ---------- Safety ----------
create table suspensions (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid references workers (id),
  agent_id uuid references agents (id),
  reason text not null,
  started_at timestamptz not null default now(),
  lifted_at timestamptz,
  check (worker_id is not null or agent_id is not null)
);

-- ---------- Public payout ledger (no personal details) ----------
create view public_ledger as
select j.id as job_id, j.tier, j.pay_cents, j.is_pilot_credit, j.status,
       coalesce(p.paid_at, j.updated_at) as recorded_at
from jobs j left join payouts p on p.job_id = j.id
where j.status in ('approved', 'paid');

-- ---------- Row Level Security (lock everything by default) ----------
alter table workers enable row level security;
alter table developers enable row level security;
alter table agents enable row level security;
alter table agent_keys enable row level security;
alter table jobs enable row level security;
alter table job_proofs enable row level security;
alter table ratings enable row level security;
alter table escrows enable row level security;
alter table payouts enable row level security;
alter table suspensions enable row level security;
alter table cu_rates enable row level security;
alter table tier_units enable row level security;

create policy "workers read own" on workers for select using (auth.uid() = id);
create policy "workers update own" on workers for update using (auth.uid() = id);
create policy "developers read own" on developers for select using (auth.uid() = id);
create policy "developers manage own agents" on agents for all using (developer_id = auth.uid());
create policy "open jobs visible to workers" on jobs for select
  using (status = 'open' or worker_id = auth.uid());
create policy "workers see own payouts" on payouts for select using (worker_id = auth.uid());
create policy "anyone reads pay floor" on cu_rates for select using (true);
create policy "anyone reads tiers" on tier_units for select using (true);
-- The AI server (Phase 2) uses the service role, which bypasses RLS.
