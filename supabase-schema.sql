-- ============================================================
--  Kocia Tabliczka — schemat bazy
--  Wklej całość do Supabase → SQL Editor → Run.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- tabele ----------
create table if not exists public.families (
  id          uuid primary key default gen_random_uuid(),
  code        text unique not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  role        text not null default 'child' check (role in ('child','parent')),
  name        text not null default 'Bez imienia',
  family_id   uuid references public.families on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.progress (
  user_id     uuid primary key references auth.users on delete cascade,
  state       jsonb not null,
  mastered    int  not null default 0,
  total       int  not null default 0,
  streak      int  not null default 0,
  accuracy    int  not null default 0,
  minutes     int  not null default 0,
  updated_at  timestamptz not null default now()
);

create table if not exists public.sessions (
  id          bigserial primary key,
  user_id     uuid not null references auth.users on delete cascade,
  mode        text,
  score       int,
  correct     int,
  total       int,
  ms          int,
  created_at  timestamptz not null default now()
);
create index if not exists sessions_user_time on public.sessions(user_id, created_at desc);

-- ---------- funkcje pomocnicze (omijają RLS, żeby nie było rekurencji) ----------
create or replace function public.my_family_id()
returns uuid language sql stable security definer set search_path = public as $$
  select family_id from public.profiles where id = auth.uid()
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- czy dany użytkownik jest dzieckiem w mojej rodzinie
create or replace function public.shares_my_family(target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = target
      and p.family_id is not null
      and p.family_id = public.my_family_id()
  )
$$;

-- ---------- parowanie ----------
create or replace function public.create_family()
returns text language plpgsql security definer set search_path = public as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- bez znaków mylących
  c text;
  fid uuid;
  i int;
begin
  if auth.uid() is null then raise exception 'brak zalogowanego użytkownika'; end if;
  loop
    c := '';
    for i in 1..6 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.families where code = c);
  end loop;
  insert into public.families(code) values (c) returning id into fid;
  update public.profiles set family_id = fid where id = auth.uid();
  return c;
end $$;

create or replace function public.join_family(p_code text)
returns text language plpgsql security definer set search_path = public as $$
declare fid uuid;
begin
  if auth.uid() is null then raise exception 'brak zalogowanego użytkownika'; end if;
  select id into fid from public.families where code = upper(trim(p_code));
  if fid is null then raise exception 'Nie ma rodziny o takim kodzie'; end if;
  update public.profiles set family_id = fid where id = auth.uid();
  return upper(trim(p_code));
end $$;

-- podgląd dla rodzica: dzieci w mojej rodzinie razem z postępem
create or replace function public.family_children()
returns table (
  id uuid, name text, mastered int, total int, streak int,
  accuracy int, minutes int, updated_at timestamptz, state jsonb
) language sql stable security definer set search_path = public as $$
  select p.id, p.name,
         coalesce(g.mastered,0), coalesce(g.total,0), coalesce(g.streak,0),
         coalesce(g.accuracy,0), coalesce(g.minutes,0), g.updated_at, g.state
  from public.profiles p
  left join public.progress g on g.user_id = p.id
  where p.role = 'child'
    and p.family_id is not null
    and p.family_id = public.my_family_id()
  order by p.name
$$;

-- ---------- RLS ----------
alter table public.families enable row level security;
alter table public.profiles enable row level security;
alter table public.progress enable row level security;
alter table public.sessions enable row level security;

drop policy if exists families_read on public.families;
create policy families_read on public.families
  for select to authenticated using (id = public.my_family_id());

drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists profiles_family_read on public.profiles;
create policy profiles_family_read on public.profiles
  for select to authenticated using (public.shares_my_family(id));

drop policy if exists progress_owner on public.progress;
create policy progress_owner on public.progress
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists progress_parent_read on public.progress;
create policy progress_parent_read on public.progress
  for select to authenticated
  using (public.my_role() = 'parent' and public.shares_my_family(user_id));

drop policy if exists sessions_owner on public.sessions;
create policy sessions_owner on public.sessions
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists sessions_parent_read on public.sessions;
create policy sessions_parent_read on public.sessions
  for select to authenticated
  using (public.my_role() = 'parent' and public.shares_my_family(user_id));

grant execute on function public.create_family, public.join_family, public.family_children,
  public.my_family_id, public.my_role, public.shares_my_family to authenticated;
