-- MARC Int. 10.4. Independent training metadata; no changes to operational tables.
begin;
create table if not exists public.marc_tutorial_attempts (
  user_id uuid not null references public.perfiles(id) on delete cascade,
  attempt_id uuid not null,
  tutorial_version integer not null check (tutorial_version = 1),
  completed_steps integer not null check (completed_steps between 0 and 22),
  status text not null check (status in ('en_progreso','omitido','completado')),
  started_at timestamptz not null,
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (user_id, attempt_id),
  check ((status = 'completado') = (completed_steps = 22)),
  check ((status = 'completado') = (completed_at is not null)),
  check (status <> 'omitido' or completed_steps = 0)
);
create index if not exists marc_tutorial_attempts_owner_date on public.marc_tutorial_attempts(user_id, started_at desc);
alter table public.marc_tutorial_attempts enable row level security;
revoke all on public.marc_tutorial_attempts from public, anon, authenticated;
grant select on public.marc_tutorial_attempts to authenticated;
-- This helper is deliberately restricted to the visibility decision, not profile contents.
create or replace function public.marc_tutorial_can_read_104(p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.perfiles a join public.perfiles t on t.id = p_owner
    where a.id = auth.uid() and a.activo and t.rol = 'promotor'
      and (a.rol = 'administrador' or
        (a.rol = 'promotor' and a.id = t.id and exists (select 1 from public.sucursales s where s.id = a.sucursal_id and s.activa)) or
        (a.rol = 'supervisor' and a.sucursal_id = t.sucursal_id
         and exists (select 1 from public.sucursales s where s.id = a.sucursal_id and s.activa)))
  );
$$;
revoke all on function public.marc_tutorial_can_read_104(uuid) from public, anon, authenticated;
grant execute on function public.marc_tutorial_can_read_104(uuid) to authenticated;
drop policy if exists marc_tutorial_read_104 on public.marc_tutorial_attempts;
create policy marc_tutorial_read_104 on public.marc_tutorial_attempts for select to authenticated
using (public.marc_tutorial_can_read_104(user_id));
-- Authenticated promoters can submit only their own metadata; terminal attempts are immutable.
create or replace function public.marc_tutorial_save_104(p_attempt uuid,p_steps integer,p_status text,p_started timestamptz)
returns public.marc_tutorial_attempts language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_row public.marc_tutorial_attempts; v_now timestamptz := pg_catalog.now();
begin
  if v_uid is null or not exists (select 1 from public.perfiles p join public.sucursales s on s.id=p.sucursal_id
    where p.id=v_uid and p.activo and p.rol='promotor' and s.activa) then
    raise exception 'Capacitación no autorizada' using errcode='42501';
  end if;
  if p_attempt is null or p_steps is null or p_steps not between 0 and 22 or p_status is null or
    p_status not in ('en_progreso','omitido','completado') or (p_status='completado') <> (p_steps=22)
    or (p_status='omitido' and p_steps<>0) or p_started is null or not pg_catalog.isfinite(p_started) then
    raise exception 'Progreso inválido' using errcode='22023';
  end if;
  insert into public.marc_tutorial_attempts as t(user_id,attempt_id,tutorial_version,completed_steps,status,started_at,updated_at,completed_at)
  values(v_uid,p_attempt,1,p_steps,p_status,least(p_started,v_now),v_now,case when p_status='completado' then v_now end)
  on conflict(user_id,attempt_id) do update set
    completed_steps=excluded.completed_steps,status=excluded.status,updated_at=v_now,completed_at=excluded.completed_at
  where t.status='en_progreso' and excluded.status<>'omitido' and excluded.completed_steps>t.completed_steps;
  select * into strict v_row from public.marc_tutorial_attempts where user_id=v_uid and attempt_id=p_attempt;
  return v_row;
end;
$$;
revoke all on function public.marc_tutorial_save_104(uuid,integer,text,timestamptz) from public, anon, authenticated;
grant execute on function public.marc_tutorial_save_104(uuid,integer,text,timestamptz) to authenticated;
commit;
