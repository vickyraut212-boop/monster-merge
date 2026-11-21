-- Demo players for the leaderboard (vicky asked on 2026-11-21 for the board
-- to show about 100 players while only ~11 real players had scored).
--
-- Each demo player is a real (anonymous) auth user with a leaderboard entry,
-- flagged with leaderboard_entries.is_bot = true. They never submit runs; the
-- Daily Ranking gives them a believable score for each day on the server
-- (supabase/functions/api/daily.ts). Their all-time scores stay below the real
-- top three so the podium keeps real players.
--
-- To REMOVE every demo player later, run (or add as a new migration):
--   delete from auth.users where id in
--     (select player_id from public.leaderboard_entries where is_bot);
-- The leaderboard rows go with them (on delete cascade).

alter table public.leaderboard_entries
  add column if not exists is_bot boolean not null default false;

comment on column public.leaderboard_entries.is_bot is
  'Demo player seeded by a migration (not a real person). Hidden from clients.';

create temporary table demo_players (n int, display_name text, best_score int, achieved_at timestamptz);

insert into demo_players (n, display_name, best_score, achieved_at) values
  (1, 'Sneaky Zuzu', 427, '2026-11-13T11:07:52Z'),
  (2, 'Taro60', 696, '2026-11-19T17:19:03Z'),
  (3, 'Cosmic Zork 7428', 184, '2026-11-16T20:09:10Z'),
  (4, 'Fuzzy Gloop 6034', 3489, '2026-11-17T20:07:32Z'),
  (5, 'Luna81', 191, '2026-11-11T06:44:04Z'),
  (6, 'Cosmic Zork 7238', 364, '2026-11-11T18:07:33Z'),
  (7, 'Bouncy Goo 4843', 223, '2026-11-13T06:58:23Z'),
  (8, 'Jolly Coco', 1046, '2026-11-11T19:28:39Z'),
  (9, 'Sleepy Zuzu', 1537, '2026-11-13T02:40:41Z'),
  (10, 'Tiny Squish 4557', 219, '2026-11-09T18:35:12Z'),
  (11, 'Pip31', 354, '2026-11-17T10:45:08Z'),
  (12, 'Sparkly Coco', 375, '2026-11-14T08:50:45Z'),
  (13, 'Happy Alien 7926', 2686, '2026-11-19T20:39:53Z'),
  (14, 'Grumpy Blob 3889', 2278, '2026-11-18T01:59:42Z'),
  (15, 'Zappy Alien 4356', 1046, '2026-11-16T08:01:31Z'),
  (16, 'Zappy Alien 5863', 143, '2026-11-20T03:56:03Z'),
  (17, 'Jolly Mochi', 320, '2026-11-09T09:48:02Z'),
  (18, 'Fuzzy Jelly 3371', 2360, '2026-11-09T21:56:49Z'),
  (19, 'Zappy Bloop 7430', 347, '2026-11-08T13:02:56Z'),
  (20, 'Goofy Slime 6754', 595, '2026-11-08T13:11:27Z'),
  (21, 'Jolly Biscuit', 204, '2026-11-21T03:48:07Z'),
  (22, 'Tiny Goo 6122', 2675, '2026-11-10T08:20:53Z'),
  (23, 'Taro78', 410, '2026-11-18T03:46:02Z'),
  (24, 'Juno63', 332, '2026-11-17T11:54:58Z'),
  (25, 'Tiny Mochi', 538, '2026-11-19T08:40:25Z'),
  (26, 'Bouncy Boss 5098', 223, '2026-11-16T23:19:53Z'),
  (27, 'Fuzzy Alien 1849', 616, '2026-11-18T23:50:37Z'),
  (28, 'Jolly Blob 1254', 228, '2026-11-16T11:50:03Z'),
  (29, 'Pebble74', 521, '2026-11-09T03:57:29Z'),
  (30, 'Taro74', 703, '2026-11-16T11:43:31Z'),
  (31, 'Sparkly Zuzu', 622, '2026-11-11T04:27:53Z'),
  (32, 'Goofy Slime 9527', 145, '2026-11-17T08:35:00Z'),
  (33, 'Wobbly Zork 2581', 149, '2026-11-13T04:12:36Z'),
  (34, 'Wobbly Blob 4135', 1882, '2026-11-15T22:02:46Z'),
  (35, 'Biscuit49', 271, '2026-11-13T19:04:01Z'),
  (36, 'Happy Goo 8979', 437, '2026-11-12T13:34:43Z'),
  (37, 'Zuzu11', 2963, '2026-11-14T00:52:40Z'),
  (38, 'Cosmic Blob 7252', 180, '2026-11-10T05:29:37Z'),
  (39, 'Pip92', 226, '2026-11-19T15:50:09Z'),
  (40, 'Juno44', 148, '2026-11-17T15:00:41Z'),
  (41, 'Zappy Zuzu', 439, '2026-11-11T08:23:48Z'),
  (42, 'Giggly Zork 8497', 1762, '2026-11-10T05:24:32Z'),
  (43, 'Happy Blob 3398', 1735, '2026-11-11T22:10:02Z'),
  (44, 'Tiny Pebble', 3751, '2026-11-17T04:13:07Z'),
  (45, 'Mighty Kiwi', 2513, '2026-11-16T20:14:00Z'),
  (46, 'Sneaky Goo 3046', 3799, '2026-11-09T15:29:52Z'),
  (47, 'Zappy Gloop 7694', 4122, '2026-11-18T01:05:38Z'),
  (48, 'Tiny Goo 5385', 2986, '2026-11-08T20:10:30Z'),
  (49, 'Pixel89', 3788, '2026-11-16T03:10:15Z'),
  (50, 'Happy Gloop 5562', 961, '2026-11-12T13:39:07Z'),
  (51, 'Happy Coco', 1884, '2026-11-14T05:49:03Z'),
  (52, 'Pebble73', 317, '2026-11-13T21:23:52Z'),
  (53, 'Wobbly Boss 3885', 776, '2026-11-14T21:06:51Z'),
  (54, 'Goofy Alien 4784', 4189, '2026-11-20T19:53:14Z'),
  (55, 'Cosmic Juno', 523, '2026-11-12T20:29:28Z'),
  (56, 'Fuzzy Boss 6011', 2651, '2026-11-11T06:17:51Z'),
  (57, 'Sleepy Zork 4794', 230, '2026-11-12T20:52:04Z'),
  (58, 'Sneaky Blob 5308', 4090, '2026-11-12T15:09:30Z'),
  (59, 'Cosmic Momo', 4417, '2026-11-16T20:10:13Z'),
  (60, 'Sparkly Goo 8030', 139, '2026-11-16T08:56:55Z'),
  (61, 'Nova58', 375, '2026-11-16T00:27:35Z'),
  (62, 'Luna64', 399, '2026-11-20T02:38:07Z'),
  (63, 'Taro77', 404, '2026-11-21T03:01:35Z'),
  (64, 'Fuzzy Nova', 739, '2026-11-15T22:09:20Z'),
  (65, 'Zappy Gloop 3142', 2102, '2026-11-09T21:49:47Z'),
  (66, 'Ziggy96', 3327, '2026-11-15T15:02:02Z'),
  (67, 'Sleepy Juno', 3131, '2026-11-11T13:52:18Z'),
  (68, 'Kiwi25', 459, '2026-11-11T17:16:32Z'),
  (69, 'Jolly Slime 9474', 608, '2026-11-11T06:44:01Z'),
  (70, 'Mochi21', 126, '2026-11-15T03:28:49Z'),
  (71, 'Fuzzy Pixel', 359, '2026-11-09T18:19:11Z'),
  (72, 'Fuzzy Gloop 5753', 228, '2026-11-12T00:43:20Z'),
  (73, 'Sneaky Kiwi', 409, '2026-11-17T19:24:45Z'),
  (74, 'Grumpy Zork 8309', 203, '2026-11-09T22:53:34Z'),
  (75, 'Tiny Pixel', 2789, '2026-11-21T00:49:00Z'),
  (76, 'Sneaky Goo 5953', 4528, '2026-11-16T14:51:36Z'),
  (77, 'Zuzu60', 1169, '2026-11-19T01:44:29Z'),
  (78, 'Cosmic Zork 2069', 1321, '2026-11-19T20:01:01Z'),
  (79, 'Zappy Slime 3761', 2203, '2026-11-20T01:18:51Z'),
  (80, 'Mighty Zuzu', 364, '2026-11-20T22:02:20Z'),
  (81, 'Squishy Zuzu', 120, '2026-11-19T16:54:16Z'),
  (82, 'Zappy Slime 4346', 793, '2026-11-14T11:18:36Z'),
  (83, 'Biscuit30', 878, '2026-11-19T04:15:52Z'),
  (84, 'Grumpy Blob 9626', 467, '2026-11-09T18:14:12Z'),
  (85, 'Goofy Blob 6462', 190, '2026-11-10T02:39:19Z'),
  (86, 'Coco81', 178, '2026-11-19T12:08:40Z'),
  (87, 'Grumpy Blob 5121', 4022, '2026-11-20T11:54:59Z'),
  (88, 'Grumpy Luna', 759, '2026-11-19T08:07:39Z'),
  (89, 'Grumpy Taro', 546, '2026-11-12T13:02:35Z'),
  (90, 'Biscuit93', 415, '2026-11-10T09:21:50Z')
;

-- Stable ids (same on every run), so the migration is safe to re-apply.
insert into auth.users (instance_id, id, aud, role, is_anonymous,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,
       md5('monster-merge-demo-player-' || n)::uuid,
       'authenticated', 'authenticated', true,
       '{"provider": "anonymous", "providers": ["anonymous"]}'::jsonb, '{}'::jsonb,
       achieved_at, achieved_at
from demo_players
on conflict (id) do nothing;

insert into public.leaderboard_entries (player_id, display_name, best_score, achieved_at, last_submit_at, is_bot)
select md5('monster-merge-demo-player-' || n)::uuid, display_name, best_score, achieved_at, achieved_at, true
from demo_players
on conflict (player_id) do nothing;

drop table demo_players;
