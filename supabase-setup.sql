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

-- Admin accounts can see the list of learners. The first account created is the admin.
alter table public.learners add column if not exists is_admin boolean not null default false;

-- Lock the table. Nobody can read or write it directly from the website,
-- only through the functions below, which check the PIN.
alter table public.learners enable row level security;
revoke all on public.learners from anon, authenticated;

-- Settings the admin can change from DevPath (like the learner limit). Locked like the learners table.
create table if not exists public.dp_settings (key text primary key, value text not null);
alter table public.dp_settings enable row level security;
revoke all on public.dp_settings from anon, authenticated;
insert into public.dp_settings (key, value) values ('max_learners', '5') on conflict (key) do nothing;

-- How many accounts can exist. Admins change it in DevPath's Admin panel (starts at 5).
create or replace function public.dp_max_learners() returns integer
language sql stable security definer set search_path = public
as $$ select coalesce((select value::integer from public.dp_settings where key = 'max_learners'), 5) $$;

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
    insert into public.learners (username, pin_hash, is_admin)
      values (p_user, crypt(p_pin, gen_salt('bf')), not exists (select 1 from public.learners))
      returning * into r;
    return jsonb_build_object('created', true, 'data', r.data, 'admin', r.is_admin);
  end if;
  if r.pin_hash <> crypt(p_pin, r.pin_hash) then
    perform pg_sleep(1);  -- slows down guessing
    raise exception 'wrong_pin';
  end if;
  update public.learners set last_seen = now() where username = p_user;
  return jsonb_build_object('created', false, 'data', r.data, 'admin', r.is_admin);
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

-- Who's learning: names, XP, lessons finished, last active. Admins only. No progress details, no PINs.
drop function if exists public.dp_learners();
create or replace function public.dp_learners(p_user text, p_pin text)
returns table (username text, xp integer, lessons_done integer, last_seen timestamptz, is_admin boolean)
language plpgsql security definer
set search_path = public, extensions
as $$
declare h text; adm boolean;
begin
  select l.pin_hash, l.is_admin into h, adm from public.learners l where l.username = lower(trim(p_user));
  if h is null or h <> crypt(p_pin, h) then perform pg_sleep(1); raise exception 'wrong_pin'; end if;
  if not adm then raise exception 'not_admin'; end if;
  return query select l.username, l.xp, l.lessons_done, l.last_seen, l.is_admin from public.learners l order by l.xp desc, l.username;
end $$;

-- Admin actions from DevPath's Admin panel. Checks the admin's own PIN every time.
create or replace function public.dp_admin(p_user text, p_pin text, p_action text, p_target text default null, p_value text default null)
returns jsonb
language plpgsql security definer
set search_path = public, extensions
as $$
declare h text; adm boolean; t text; n integer;
begin
  p_user := lower(trim(p_user)); t := lower(trim(coalesce(p_target, '')));
  select l.pin_hash, l.is_admin into h, adm from public.learners l where l.username = p_user;
  if h is null or h <> crypt(p_pin, h) then perform pg_sleep(1); raise exception 'wrong_pin'; end if;
  if not adm then raise exception 'not_admin'; end if;
  if p_action = 'info' then
    return jsonb_build_object('ok', true, 'max', public.dp_max_learners());
  end if;
  if p_action in ('make_admin', 'remove_admin', 'remove', 'reset_pin')
     and not exists (select 1 from public.learners where username = t) then raise exception 'no_target'; end if;
  if p_action = 'make_admin' then
    update public.learners set is_admin = true where username = t;
  elsif p_action = 'remove_admin' then
    if t = p_user then raise exception 'not_self'; end if;
    update public.learners set is_admin = false where username = t;
  elsif p_action = 'remove' then
    if t = p_user then raise exception 'not_self'; end if;
    delete from public.learners where username = t;
  elsif p_action = 'reset_pin' then
    if coalesce(p_value, '') !~ '^[0-9]{4,8}$' then raise exception 'bad_pin'; end if;
    update public.learners set pin_hash = crypt(p_value, gen_salt('bf')) where username = t;
  elsif p_action = 'set_limit' then
    if coalesce(p_value, '') !~ '^[0-9]{1,3}$' then raise exception 'bad_limit'; end if;
    n := p_value::integer;
    if n < 1 or n > 100 then raise exception 'bad_limit'; end if;
    if n < (select count(*) from public.learners) then raise exception 'limit_below_count'; end if;
    insert into public.dp_settings (key, value) values ('max_learners', n::text)
      on conflict (key) do update set value = excluded.value;
  else
    raise exception 'bad_action';
  end if;
  return jsonb_build_object('ok', true, 'max', public.dp_max_learners());
end $$;

revoke all on function public.dp_login(text, text) from public;
revoke all on function public.dp_save(text, text, jsonb, integer, integer) from public;
revoke all on function public.dp_learners(text, text) from public;
grant execute on function public.dp_login(text, text) to anon, authenticated;
grant execute on function public.dp_save(text, text, jsonb, integer, integer) to anon, authenticated;
grant execute on function public.dp_learners(text, text) to anon, authenticated;
revoke all on function public.dp_admin(text, text, text, text, text) from public;
grant execute on function public.dp_admin(text, text, text, text, text) to anon, authenticated;

-- To make someone an admin (or remove it), change the name and run just this line:
-- update public.learners set is_admin = true where username = 'yourname';
