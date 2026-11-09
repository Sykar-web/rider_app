-- Unaccepted requests are removed when cancelled or after three minutes.
-- Scheduled rides get their search window at the scheduled pickup time.
begin;
alter table public.rides add column if not exists request_expires_at timestamptz;
alter table public.deliveries add column if not exists request_expires_at timestamptz;
update public.rides set request_expires_at=greatest(requested_at,coalesce((to_jsonb(rides)->>'scheduled_at')::timestamptz,requested_at))+interval '3 minutes' where request_expires_at is null;
update public.deliveries set request_expires_at=requested_at+interval '3 minutes' where request_expires_at is null;
create index if not exists rides_unaccepted_expiry on public.rides(request_expires_at) where status='requested' and driver_id is null;
create index if not exists deliveries_unaccepted_expiry on public.deliveries(request_expires_at) where status='requested' and courier_id is null;
create or replace function public.guard_request_expiry() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    new.request_expires_at:=greatest(now(),coalesce((to_jsonb(new)->>'scheduled_at')::timestamptz,now()))+interval '3 minutes';
  else
    new.request_expires_at:=old.request_expires_at;
    if old.status::text='requested' and new.status::text in ('accepted','arriving','in_progress','picked_up') and old.request_expires_at<=now() then raise exception 'This request expired. Choose another request.'; end if;
  end if;
  return new;
end $$;
drop trigger if exists guard_request_expiry on public.rides;
create trigger guard_request_expiry before insert or update on public.rides for each row execute function public.guard_request_expiry();
drop trigger if exists guard_request_expiry on public.deliveries;
create trigger guard_request_expiry before insert or update on public.deliveries for each row execute function public.guard_request_expiry();
create or replace function public.cancel_unaccepted_request(p_kind text,p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare booking jsonb;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if p_kind='rides' then select to_jsonb(r) into booking from public.rides r where id=p_id for update;
  elsif p_kind='deliveries' then select to_jsonb(d) into booking from public.deliveries d where id=p_id for update;
  else raise exception 'Unknown request type'; end if;
  if booking is null then return; end if;
  if coalesce(booking->>'passenger_id',booking->>'sender_id') is distinct from auth.uid()::text then raise exception using errcode='42501',message='This is not your request'; end if;
  if booking->>'status'<>'requested' or coalesce(booking->>'driver_id',booking->>'courier_id',booking->>'accepted_at') is not null then raise exception 'This request has already been accepted or closed'; end if;
  if p_kind='rides' then delete from public.rides where id=p_id; else delete from public.deliveries where id=p_id; end if;
end $$;
create or replace function public.purge_unaccepted_requests() returns void language plpgsql security definer set search_path='' as $$
begin
  delete from public.rides where status='requested' and driver_id is null and accepted_at is null and request_expires_at<=now();
  delete from public.deliveries where status='requested' and courier_id is null and accepted_at is null and request_expires_at<=now();
end $$;
create or replace function public.expire_my_requests() returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then return; end if;
  delete from public.rides where passenger_id=auth.uid() and status='requested' and driver_id is null and accepted_at is null and request_expires_at<=now();
  delete from public.deliveries where sender_id=auth.uid() and status='requested' and courier_id is null and accepted_at is null and request_expires_at<=now();
end $$;
-- Cover older app versions and administrative cancellation as well.
create or replace function public.remove_cancelled_unaccepted_request() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.status::text='requested' and new.status::text='cancelled' and coalesce(to_jsonb(old)->>'driver_id',to_jsonb(old)->>'courier_id',to_jsonb(old)->>'accepted_at') is null and coalesce(to_jsonb(new)->>'driver_id',to_jsonb(new)->>'courier_id',to_jsonb(new)->>'accepted_at') is null then
    if tg_table_name='rides' then delete from public.rides where id=new.id; else delete from public.deliveries where id=new.id; end if;
  end if;
  return new;
end $$;
drop trigger if exists remove_cancelled_unaccepted_request on public.rides;
create trigger remove_cancelled_unaccepted_request after update on public.rides for each row execute function public.remove_cancelled_unaccepted_request();
drop trigger if exists remove_cancelled_unaccepted_request on public.deliveries;
create trigger remove_cancelled_unaccepted_request after update on public.deliveries for each row execute function public.remove_cancelled_unaccepted_request();
revoke all on function public.guard_request_expiry(),public.cancel_unaccepted_request(text,uuid),public.purge_unaccepted_requests(),public.expire_my_requests(),public.remove_cancelled_unaccepted_request() from public,anon,authenticated;
grant execute on function public.cancel_unaccepted_request(text,uuid),public.expire_my_requests() to authenticated;
grant execute on function public.purge_unaccepted_requests() to service_role;
commit;
-- Runs even when phones/browsers are closed. The UI clears at the deadline;
-- this sweep removes abandoned requests within 10 seconds of that deadline.
create extension if not exists pg_cron;
select cron.schedule('fastride-expire-unaccepted','10 seconds','select public.purge_unaccepted_requests()');
