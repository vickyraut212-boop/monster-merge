-- All-time leaderboard.
--
-- leaderboard_entries: one row per player (their best score and display name).
--   Public data: everyone may read it, no client may write it. Rows are written
--   only by the submit-score and set-display-name Edge Functions (service role).
--
-- score_runs: every submitted run, kept for auditing (finding cheated scores)
--   and so weekly/daily boards can be built later. Service role only.

create table public.leaderboard_entries (
  player_id       uuid primary key references auth.users (id) on delete cascade,
  display_name    text not null check (char_length(display_name) between 3 and 16),
  best_score      integer not null default 0 check (best_score >= 0),
  achieved_at     timestamptz,
  last_submit_at  timestamptz,
  created_at      timestamptz not null default now()
);

comment on table public.leaderboard_entries is
  'All-time best score per player. Public read-only; written by Edge Functions.';

-- Ranking order: higher score first; on a tie, whoever got there first.
create index leaderboard_entries_rank_idx
  on public.leaderboard_entries (best_score desc, achieved_at asc);

alter table public.leaderboard_entries enable row level security;

create policy "leaderboard is readable by everyone"
  on public.leaderboard_entries
  for select
  to anon, authenticated
  using (true);

-- Supabase grants everything on new public tables to anon/authenticated by
-- default. Take that back and allow reading only the public columns
-- (last_submit_at and created_at stay hidden). Writes stay blocked twice over:
-- no privilege and no RLS policy.
revoke all on public.leaderboard_entries from anon, authenticated;
grant select (player_id, display_name, best_score, achieved_at)
  on public.leaderboard_entries to anon, authenticated;


create table public.score_runs (
  id           bigint generated always as identity primary key,
  player_id    uuid not null references auth.users (id) on delete cascade,
  score        integer not null check (score >= 0),
  duration_ms  integer not null check (duration_ms >= 0),
  drops        integer not null check (drops >= 0),
  created_at   timestamptz not null default now()
);

comment on table public.score_runs is
  'Every submitted run. Private: no client access, service role only.';

create index score_runs_player_idx on public.score_runs (player_id, created_at desc);
create index score_runs_created_idx on public.score_runs (created_at desc);

-- RLS on with no policies, and no privileges: anon/authenticated cannot read or write.
alter table public.score_runs enable row level security;
revoke all on public.score_runs from anon, authenticated;
