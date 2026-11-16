-- Navoo: store every user's app data in Supabase.
-- Run once in Supabase > SQL Editor > New query > Run.

-- 1. One private record per user.
create table if not exists public.user_state (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  email      text,
  state      jsonb not null default '{}'::jsonb,   -- Vision, Focus, Micro-Actions, Brain Cheat Codes, rewards, check-ins, chat, settings
  learnings  jsonb not null default '[]'::jsonb,   -- what the coach has learned about this user
  updated_at timestamptz not null default now()
);

-- 2. Each user can only see and change their own record.
alter table public.user_state enable row level security;

drop policy if exists "own row select" on public.user_state;
drop policy if exists "own row insert" on public.user_state;
drop policy if exists "own row update" on public.user_state;
drop policy if exists "own row delete" on public.user_state;
create policy "own row select" on public.user_state for select to authenticated using (auth.uid() = user_id);
create policy "own row insert" on public.user_state for insert to authenticated with check (auth.uid() = user_id);
create policy "own row update" on public.user_state for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own row delete" on public.user_state for delete to authenticated using (auth.uid() = user_id);

-- 3. "Delete account" in the app removes the login and all data (Google Play requirement).
create or replace function public.delete_me()
returns void
language sql
security definer
set search_path = public
as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_me() from public, anon;
grant execute on function public.delete_me() to authenticated;
