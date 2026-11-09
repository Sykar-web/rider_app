-- Requires the shared driver application setup and base FastRide tables.
-- Configure the PIN with the ignored, private fast_ride_admin_setup.sql file.
begin;
create table if not exists public.admin_pin_config (
  singleton boolean primary key default true check(singleton), salt text not null, pin_hash text not null
);
create table if not exists public.admin_pin_attempts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  attempts integer not null default 0, locked_until timestamptz
);
create table if not exists public.admin_dashboard_sessions (
  user_id uuid references auth.users(id) on delete cascade,
  session_id text not null, unlocked_until timestamptz not null,
  primary key(user_id,session_id)
);
create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id),
  action text not null, subject_id uuid, detail jsonb not null default '{}', created_at timestamptz not null default now()
);
alter table public.admin_pin_config enable row level security;
alter table public.admin_pin_attempts enable row level security;
alter table public.admin_dashboard_sessions enable row level security;
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_pin_config,public.admin_pin_attempts,public.admin_dashboard_sessions,public.admin_audit_log from public,anon,authenticated;
alter table public.driver_applications add column if not exists review_note text;
alter table public.driver_applications add column if not exists reviewed_by uuid;
alter table public.driver_applications add column if not exists reviewed_at timestamptz;
alter table public.rides add column if not exists cancelled_at timestamptz;
alter table public.deliveries add column if not exists cancelled_at timestamptz;
alter table public.rides add column if not exists fare_ugx numeric;
alter table public.deliveries add column if not exists fare_ugx numeric;

create table if not exists public.bus_companies(id uuid primary key default gen_random_uuid(),name text not null unique,is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.bus_schedules(id uuid primary key default gen_random_uuid(),company_id uuid not null references public.bus_companies(id),origin text not null,destination text not null,departure_time time not null,arrival_time time not null,duration_minutes integer not null check(duration_minutes>0),service_class text not null check(service_class in ('ordinary','executive')),total_seats integer not null check(total_seats between 1 and 80),is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.support_requests(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),category text not null,message text not null,status text not null default 'open' check(status in ('open','in_review','resolved')),response text,created_at timestamptz not null default now());
alter table public.bus_companies enable row level security;
alter table public.bus_schedules enable row level security;
alter table public.support_requests enable row level security;
grant select on public.bus_companies,public.bus_schedules to authenticated;
drop policy if exists "FastRide available bus companies" on public.bus_companies;
create policy "FastRide available bus companies" on public.bus_companies for select to authenticated using(is_active);
drop policy if exists "FastRide available bus schedules" on public.bus_schedules;
create policy "FastRide available bus schedules" on public.bus_schedules for select to authenticated using(is_active and exists(select 1 from public.bus_companies c where c.id=company_id and c.is_active));
grant select,insert on public.support_requests to authenticated;
drop policy if exists "FastRide own support read" on public.support_requests;
create policy "FastRide own support read" on public.support_requests for select to authenticated using(user_id=auth.uid());
drop policy if exists "FastRide own support request" on public.support_requests;
create policy "FastRide own support request" on public.support_requests for insert to authenticated with check(user_id=auth.uid() and status='open' and response is null and category in ('ride_issue','lost_item','general','privacy') and length(message) between 1 and 2000);

create or replace function public.admin_is_account() returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from auth.users where id=auth.uid() and lower(email)='ezrasykar@gmail.com' and email_confirmed_at is not null);
$$;
create or replace function public.admin_is_unlocked() returns boolean
language sql stable security definer set search_path='' as $$
  select public.admin_is_account() and exists(select 1 from public.admin_dashboard_sessions
    where user_id=auth.uid() and session_id=auth.jwt()->>'session_id' and unlocked_until>now());
$$;

create or replace function public.admin_unlock_dashboard(p_pin text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.admin_pin_attempts; c public.admin_pin_config; until_time timestamptz;
begin
  if not public.admin_is_account() or nullif(auth.jwt()->>'session_id','') is null then return jsonb_build_object('ok',false); end if;
  insert into public.admin_pin_attempts(user_id) values(auth.uid()) on conflict do nothing;
  select * into a from public.admin_pin_attempts where user_id=auth.uid() for update;
  if a.locked_until>now() then return jsonb_build_object('ok',false,'retry_after',ceil(extract(epoch from a.locked_until-now()))); end if;
  if a.locked_until is not null then a.attempts:=0; end if;
  select * into c from public.admin_pin_config where singleton;
  if c.pin_hash is null then raise exception 'Admin setup is incomplete'; end if;
  if p_pin ~ '^[0-9]{4}$' and encode(sha256(convert_to(c.salt||':'||p_pin,'UTF8')),'hex')=c.pin_hash then
    until_time:=now()+interval '15 minutes';
    update public.admin_pin_attempts set attempts=0,locked_until=null where user_id=auth.uid();
    insert into public.admin_dashboard_sessions values(auth.uid(),auth.jwt()->>'session_id',until_time)
      on conflict(user_id,session_id) do update set unlocked_until=excluded.unlocked_until;
    insert into public.admin_audit_log(actor_id,action) values(auth.uid(),'dashboard_unlocked');
    return jsonb_build_object('ok',true,'expires_at',until_time);
  end if;
  update public.admin_pin_attempts set attempts=a.attempts+1,locked_until=case when a.attempts+1>=5 then now()+interval '15 minutes' end where user_id=auth.uid();
  return jsonb_build_object('ok',false,'retry_after',case when a.attempts+1>=5 then 900 else 0 end);
end $$;

create or replace function public.admin_lock_dashboard() returns void
language plpgsql security definer set search_path='' as $$
begin delete from public.admin_dashboard_sessions where user_id=auth.uid() and session_id=auth.jwt()->>'session_id'; end $$;

create or replace function public.admin_dashboard_data(p_section text,p_search text default '',p_page integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare rows jsonb; stats jsonb; pattern text:='%'||left(coalesce(p_search,''),200)||'%'; skip integer:=greatest(0,least(coalesce(p_page,0),1000))*50;
begin
  if not public.admin_is_unlocked() then raise exception using errcode='42501',message='Unlock the admin dashboard again'; end if;
  case p_section
  when 'overview' then
    select jsonb_build_object('accounts',(select count(*) from auth.users),'approved_drivers',(select count(*) from auth.users where raw_app_meta_data->>'driver_approved'='true'),'pending_applications',(select count(*) from public.driver_applications where status='pending'),'open_support',(select count(*) from public.support_requests where status<>'resolved'),'rides',(select count(*) from public.rides),'deliveries',(select count(*) from public.deliveries),'recorded_fares_ugx',coalesce((select sum(fare_ugx) from public.rides where status='completed'),0)+coalesce((select sum(fare_ugx) from public.deliveries where status='completed'),0)) into stats;
  when 'applications' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(a)||jsonb_build_object('email',u.email,'avatar_path',p.avatar_path) data from public.driver_applications a join auth.users u on u.id=a.user_id left join public.profiles p on p.id=a.user_id where (coalesce(a.details->>'full_name','')||' '||coalesce(u.email,'')||' '||a.status) ilike pattern order by (a.status='pending') desc,a.updated_at desc limit 50 offset skip)x;
  when 'people' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(p)||jsonb_build_object('email',u.email,'driver_approved',u.raw_app_meta_data->>'driver_approved'='true') data from public.profiles p join auth.users u on u.id=p.id where (coalesce(p.full_name,'')||' '||coalesce(u.email,'')||' '||coalesce(p.phone,'')) ilike pattern order by u.created_at desc limit 50 offset skip)x;
  when 'rides' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(r) data from public.rides r where r::text ilike pattern order by coalesce(to_jsonb(r)->>'requested_at','') desc limit 50 offset skip)x;
  when 'deliveries' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(r) data from public.deliveries r where r::text ilike pattern order by coalesce(to_jsonb(r)->>'requested_at','') desc limit 50 offset skip)x;
  when 'support' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(s) data from public.support_requests s where s::text ilike pattern order by s.created_at desc limit 50 offset skip)x;
  when 'companies' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(c) data from public.bus_companies c where c.name ilike pattern order by c.name limit 50 offset skip)x;
  when 'schedules' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(s)||jsonb_build_object('company_name',c.name) data from public.bus_schedules s join public.bus_companies c on c.id=s.company_id where (c.name||' '||s.origin||' '||s.destination) ilike pattern order by s.created_at desc limit 50 offset skip)x;
  when 'audit' then
    select jsonb_agg(x.data) into rows from (select to_jsonb(a) data from public.admin_audit_log a where a::text ilike pattern order by a.created_at desc limit 50 offset skip)x;
  else raise exception 'Unknown admin section';
  end case;
  return jsonb_build_object('stats',coalesce(stats,'{}'::jsonb),'rows',coalesce(rows,'[]'::jsonb));
end $$;

create or replace function public.admin_dashboard_action(p_action text,p_target uuid default null,p_details jsonb default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare approved boolean:=coalesce((p_details->>'approved')::boolean,false); reason text:=btrim(coalesce(p_details->>'reason','')); affected integer; old_schedule public.bus_schedules;
begin
  if not public.admin_is_unlocked() then raise exception using errcode='42501',message='Unlock the admin dashboard again'; end if;
  if octet_length(p_details::text)>16384 then raise exception 'Details are too long'; end if;
  case p_action
  when 'review_application' then
    if not approved and length(reason)<3 then raise exception 'Give a reason for rejecting the application'; end if;
    perform public.review_driver_application(p_target,approved);
    update public.driver_applications set review_note=left(reason,2000),reviewed_by=auth.uid(),reviewed_at=now() where user_id=p_target;
  when 'driver_access' then
    if length(reason)<3 then raise exception 'Give a reason for this account change'; end if;
    perform pg_advisory_xact_lock(hashtextextended('driver:'||p_target::text,0));
    if exists(select 1 from public.rides where driver_id=p_target and status in ('accepted','arriving','in_progress')) or exists(select 1 from public.deliveries where courier_id=p_target and status in ('accepted','picked_up')) then raise exception 'Finish or cancel the active booking before changing driver access'; end if;
    if approved and not exists(select 1 from public.driver_applications where user_id=p_target and status='approved') then raise exception 'Approve the driver application first'; end if;
    update auth.users set raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||jsonb_build_object('driver_approved',approved) where id=p_target;
    get diagnostics affected=row_count; if affected<>1 then raise exception 'Account not found'; end if;
    update public.profiles set is_online=false where id=p_target;
  when 'cancel_booking' then
    if length(reason)<3 then raise exception 'Give a cancellation reason'; end if;
    if p_details->>'kind'='rides' then update public.rides set status='cancelled',cancelled_at=now() where id=p_target and status not in ('completed','cancelled');
    elsif p_details->>'kind'='deliveries' then update public.deliveries set status='cancelled',cancelled_at=now() where id=p_target and status not in ('completed','cancelled');
    else raise exception 'Unknown booking type'; end if;
    get diagnostics affected=row_count; if affected<>1 then raise exception 'Booking is already closed or unavailable'; end if;
  when 'support_reply' then
    if length(coalesce(p_details->>'response','')) not between 1 and 2000 or p_details->>'status' not in ('open','in_review','resolved') then raise exception 'Enter a response and valid status'; end if;
    update public.support_requests set response=p_details->>'response',status=p_details->>'status' where id=p_target;
    get diagnostics affected=row_count; if affected<>1 then raise exception 'Support request not found'; end if;
  when 'save_company' then
    if length(btrim(coalesce(p_details->>'name',''))) not between 2 and 100 then raise exception 'Enter a company name'; end if;
    if p_target is null then insert into public.bus_companies(name,is_active) values(btrim(p_details->>'name'),coalesce((p_details->>'is_active')::boolean,true)) returning id into p_target;
    else update public.bus_companies set name=btrim(p_details->>'name'),is_active=coalesce((p_details->>'is_active')::boolean,true) where id=p_target; get diagnostics affected=row_count; if affected<>1 then raise exception 'Company not found'; end if; end if;
  when 'save_schedule' then
    if nullif(btrim(p_details->>'origin'),'') is null or nullif(btrim(p_details->>'destination'),'') is null or coalesce(p_details->>'service_class','') not in ('ordinary','executive') or coalesce((p_details->>'total_seats')::integer,0) not between 1 and 80 or coalesce((p_details->>'duration_minutes')::integer,0)<1 then raise exception 'Enter a valid route, class, capacity and travel duration'; end if;
    if p_target is not null then
      select * into old_schedule from public.bus_schedules where id=p_target for update;
      if not found then raise exception 'Schedule not found'; end if;
      if exists(select 1 from public.rides where bus_schedule_id=p_target and status not in ('cancelled','completed')) and
        (old_schedule.company_id::text is distinct from p_details->>'company_id' or old_schedule.origin is distinct from p_details->>'origin' or old_schedule.destination is distinct from p_details->>'destination' or old_schedule.departure_time is distinct from (p_details->>'departure_time')::time or old_schedule.arrival_time is distinct from (p_details->>'arrival_time')::time or old_schedule.total_seats is distinct from (p_details->>'total_seats')::integer or old_schedule.service_class is distinct from p_details->>'service_class' or old_schedule.duration_minutes is distinct from (p_details->>'duration_minutes')::integer) then raise exception 'This departure has bookings; create another schedule instead of changing their tickets'; end if;
    end if;
    insert into public.bus_schedules(id,company_id,origin,destination,departure_time,arrival_time,duration_minutes,service_class,total_seats,is_active)
      values(coalesce(p_target,gen_random_uuid()),(p_details->>'company_id')::uuid,btrim(p_details->>'origin'),btrim(p_details->>'destination'),(p_details->>'departure_time')::time,(p_details->>'arrival_time')::time,(p_details->>'duration_minutes')::integer,p_details->>'service_class',(p_details->>'total_seats')::integer,coalesce((p_details->>'is_active')::boolean,true))
      on conflict(id) do update set company_id=excluded.company_id,origin=excluded.origin,destination=excluded.destination,departure_time=excluded.departure_time,arrival_time=excluded.arrival_time,duration_minutes=excluded.duration_minutes,service_class=excluded.service_class,total_seats=excluded.total_seats,is_active=excluded.is_active returning id into p_target;
  else raise exception 'Unknown admin action';
  end case;
  insert into public.admin_audit_log(actor_id,action,subject_id,detail) values(auth.uid(),p_action,p_target,p_details);
end $$;

-- Protect approval checks even if an older installation has permissive dispatch RLS.
create or replace function public.enforce_approved_driver() returns trigger language plpgsql security definer set search_path='' as $$
declare owner_id uuid; state text;
begin
  if public.admin_is_unlocked() then return new; end if;
  if tg_table_name='profiles' then
    if new.is_online is not true then return new; end if; owner_id:=new.id;
  else
    state:=to_jsonb(new)->>'status'; if state not in ('accepted','arriving','in_progress','picked_up') then return new; end if;
    owner_id:=coalesce(to_jsonb(new)->>'driver_id',to_jsonb(new)->>'courier_id')::uuid;
  end if;
  if owner_id is null then raise exception 'An approved driver is required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('driver:'||owner_id::text,0));
  if not exists(select 1 from auth.users where id=owner_id and raw_app_meta_data->>'driver_approved'='true') then raise exception 'Driver approval is required'; end if;
  return new;
end $$;
drop trigger if exists enforce_approved_driver on public.rides;
create trigger enforce_approved_driver before insert or update on public.rides for each row execute function public.enforce_approved_driver();
drop trigger if exists enforce_approved_driver on public.deliveries;
create trigger enforce_approved_driver before insert or update on public.deliveries for each row execute function public.enforce_approved_driver();
drop trigger if exists enforce_approved_driver on public.profiles;
create trigger enforce_approved_driver before insert or update on public.profiles for each row execute function public.enforce_approved_driver();

drop policy if exists "Admin document review" on storage.objects;
create policy "Admin document review" on storage.objects for select to authenticated using(bucket_id in ('driver-documents','profile-photos') and public.admin_is_unlocked());
revoke all on function public.admin_is_account(),public.admin_is_unlocked(),public.admin_unlock_dashboard(text),public.admin_lock_dashboard(),public.admin_dashboard_data(text,text,integer),public.admin_dashboard_action(text,uuid,jsonb),public.enforce_approved_driver() from public,anon;
grant execute on function public.admin_is_account(),public.admin_is_unlocked(),public.admin_unlock_dashboard(text),public.admin_lock_dashboard(),public.admin_dashboard_data(text,text,integer),public.admin_dashboard_action(text,uuid,jsonb) to authenticated;
commit;
