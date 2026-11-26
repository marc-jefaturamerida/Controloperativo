-- MARC 10.6: independent repeat requests, immutable history, no operational writes.
begin;
create table if not exists public.marc_tutorial_requests (
  request_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.perfiles(id) on delete cascade,
  requested_by uuid references public.perfiles(id) on delete set null,
  tutorial_version integer not null default 1 check (tutorial_version=1),
  requested_at timestamptz not null default now()
);
create index if not exists marc_tutorial_requests_owner_date on public.marc_tutorial_requests(user_id,requested_at desc);
alter table public.marc_tutorial_requests enable row level security;
revoke all on public.marc_tutorial_requests from public, anon, authenticated;
grant select on public.marc_tutorial_requests to authenticated;
drop policy if exists marc_tutorial_request_read_106 on public.marc_tutorial_requests;
create policy marc_tutorial_request_read_106 on public.marc_tutorial_requests for select to authenticated
using (public.marc_tutorial_can_read_104(user_id));
-- Serialize repeat creation per target. Existing pending requests are returned, not duplicated.
-- A request is answered by the attempt with the same UUID (accepted or omitted).
create or replace function public.marc_tutorial_request_106(p_owner uuid)
returns public.marc_tutorial_requests language plpgsql security definer set search_path='' as $$
declare v_uid uuid := auth.uid(); v_row public.marc_tutorial_requests;
begin
  if v_uid is null or not exists(select 1 from public.perfiles p where p.id=v_uid and p.activo and p.rol='administrador') then
    raise exception 'Solicitud de capacitación no autorizada' using errcode='42501';
  end if;
  perform 1 from public.perfiles p join public.sucursales s on s.id=p.sucursal_id
    where p.id=p_owner and p.rol='promotor' and p.activo and s.activa for update of p;
  if not found then raise exception 'El promotor o su sucursal no están activos' using errcode='22023'; end if;
  select q.* into v_row from public.marc_tutorial_requests q
    where q.user_id=p_owner and q.tutorial_version=1 and not exists (
      select 1 from public.marc_tutorial_attempts a where a.user_id=q.user_id and a.attempt_id=q.request_id)
    order by q.requested_at desc,q.request_id limit 1;
  if found then return v_row; end if;
  insert into public.marc_tutorial_requests(user_id,requested_by) values(p_owner,v_uid) returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.marc_tutorial_request_106(uuid) from public, anon, authenticated;
grant execute on function public.marc_tutorial_request_106(uuid) to authenticated;
commit;
