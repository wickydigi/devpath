-- DevPath accounts: paste this whole file into Supabase → SQL Editor → Run.
-- Safe to run again: it only adds what's missing and updates the functions.

create extension if not exists pgcrypto with schema extensions;

-- One row per learner. Progress is a small JSON document (a few KB).
create table if not exists public.learners (
  username     text primary key check (username ~ '^[a-z0-9_]{3,20}$'),
  pin_hash     text not null,
  data         jsonb not null default '{}'::jsonb,
  xp           integer not null default 0,
  lessons_done integer not null default 0,
  created_at   timestamptz not null default now(),
  last_seen    timestamptz not null default now()
);

-- Lock the table. Nobody can read or write it directly from the website,
-- only through the three functions below, which check the PIN.
alter table public.learners enable row level security;
revoke all on public.learners from anon, authenticated;

-- How many accounts can exist. Change 5 to allow more people.
create or replace function public.dp_max_learners() returns integer
language sql immutable as $$ select 5 $$;

-- Sign in. Creates the account the first time a username is used.
create or replace function public.dp_login(p_user text, p_pin text)
returns jsonb
language plpgsql security definer
set search_path = public, extensions
as $$
declare r public.learners;
begin
  p_user := lower(trim(p_user));
  if p_user !~ '^[a-z0-9_]{3,20}$' then raise exception 'bad_username'; end if;
  if p_pin !~ '^[0-9]{4,8}$' then raise exception 'bad_pin'; end if;
  select * into r from public.learners where username = p_user;
  if not found then
    perform pg_advisory_xact_lock(4242);
    if (select count(*) from public.learners) >= public.dp_max_learners() then raise exception 'full'; end if;
    insert into public.learners (username, pin_hash) values (p_user, crypt(p_pin, gen_salt('bf'))) returning * into r;
    return jsonb_build_object('created', true, 'data', r.data);
  end if;
  if r.pin_hash <> crypt(p_pin, r.pin_hash) then
    perform pg_sleep(1);  -- slows down guessing
    raise exception 'wrong_pin';
  end if;
  update public.learners set last_seen = now() where username = p_user;
  return jsonb_build_object('created', false, 'data', r.data);
end $$;

-- Save progress.
create or replace function public.dp_save(p_user text, p_pin text, p_data jsonb, p_xp integer, p_done integer)
returns timestamptz
language plpgsql security definer
set search_path = public, extensions
as $$
declare h text;
begin
  p_user := lower(trim(p_user));
  select pin_hash into h from public.learners where username = p_user;
  if h is null then raise exception 'no_user'; end if;
  if h <> crypt(p_pin, h) then perform pg_sleep(1); raise exception 'wrong_pin'; end if;
  if octet_length(p_data::text) > 300000 then raise exception 'too_big'; end if;
  update public.learners
     set data = p_data, xp = coalesce(p_xp, 0), lessons_done = coalesce(p_done, 0), last_seen = now()
   where username = p_user;
  return now();
end $$;

-- Who's learning: names, XP, lessons finished, last active. No progress details, no PINs.
create or replace function public.dp_learners()
returns table (username text, xp integer, lessons_done integer, last_seen timestamptz)
language sql security definer
set search_path = public
as $$ select username, xp, lessons_done, last_seen from public.learners order by xp desc, username $$;

revoke all on function public.dp_login(text, text) from public;
revoke all on function public.dp_save(text, text, jsonb, integer, integer) from public;
revoke all on function public.dp_learners() from public;
grant execute on function public.dp_login(text, text) to anon, authenticated;
grant execute on function public.dp_save(text, text, jsonb, integer, integer) to anon, authenticated;
grant execute on function public.dp_learners() to anon, authenticated;
