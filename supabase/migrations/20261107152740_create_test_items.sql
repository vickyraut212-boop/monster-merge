-- Test table to confirm the CI pipeline reaches the hosted database.
-- Follows the "public data" rule: anyone may read it, no client may write it.
-- Safe to drop later with a new migration once real tables exist.

create table public.test_items (
  id          bigint generated always as identity primary key,
  name        text not null,
  tier        smallint not null check (tier between 1 and 7),
  created_at  timestamptz not null default now()
);

comment on table public.test_items is 'Pipeline smoke test. Public read-only.';

alter table public.test_items enable row level security;

-- Read-only for everyone (anonymous and signed-in players). No insert/update/delete policies,
-- so clients cannot write; only the service role (Edge Functions, dashboard) can.
create policy "test_items are readable by everyone"
  on public.test_items
  for select
  to anon, authenticated
  using (true);

grant select on public.test_items to anon, authenticated;

-- Seed rows live in the migration (not seed.sql) because `supabase db push`
-- does not run seed.sql against the hosted project.
insert into public.test_items (name, tier) values
  ('Tiny Dot', 1),
  ('Tier 2 Monster', 2),
  ('Tier 3 Monster', 3),
  ('Tier 4 Monster', 4),
  ('Tier 5 Monster', 5),
  ('Tier 6 Monster', 6),
  ('Big Boss', 7);
