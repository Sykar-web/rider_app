-- FastRide bus booking foundation: companies, published departures, and
-- seat/whole-bus reservations. Keep departure data maintained by an admin.

create table if not exists public.bus_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.bus_schedules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.bus_companies(id) on delete cascade,
  origin text not null default 'Arua',
  destination text not null default 'Kampala',
  departure_time time not null,
  arrival_time time not null,
  duration_minutes integer not null check (duration_minutes > 0),
  service_class text not null check (service_class in ('ordinary', 'executive')),
  total_seats integer not null default 45 check (total_seats between 1 and 80),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, origin, destination, departure_time, service_class)
);

alter table public.rides
  add column if not exists bus_schedule_id uuid references public.bus_schedules(id),
  add column if not exists travel_date date,
  add column if not exists travel_class text,
  add column if not exists seat_numbers text[];

drop index if exists public.rides_active_bus_seat_unique;

create or replace function public.prevent_bus_reservation_conflicts()
returns trigger language plpgsql as $$
begin
  if new.vehicle_type <> 'bus' or new.bus_schedule_id is null or new.travel_date is null then return new; end if;
  if new.reservation_type = 'individual' and (new.seat_numbers is null or cardinality(new.seat_numbers) = 0) then
    new.seat_numbers := array[new.seat_number];
  end if;
  if new.reservation_type = 'whole_bus' and exists (
    select 1 from public.rides r where r.bus_schedule_id = new.bus_schedule_id
      and r.travel_date = new.travel_date and r.status not in ('cancelled', 'completed') and r.id is distinct from new.id
  ) then raise exception 'This bus already has passenger reservations for that departure.'; end if;
  if new.reservation_type = 'individual' and exists (
    select 1 from public.rides r where r.bus_schedule_id = new.bus_schedule_id
      and r.travel_date = new.travel_date and r.reservation_type = 'whole_bus'
      and r.status not in ('cancelled', 'completed') and r.id is distinct from new.id
  ) then raise exception 'This departure has been reserved as a whole bus.'; end if;
  if new.reservation_type = 'individual' and exists (
    select 1 from public.rides r, unnest(coalesce(r.seat_numbers, array[r.seat_number])) reserved_seat
    where r.bus_schedule_id = new.bus_schedule_id and r.travel_date = new.travel_date
      and r.reservation_type = 'individual' and r.status not in ('cancelled', 'completed')
      and r.id is distinct from new.id and reserved_seat = any(new.seat_numbers)
  ) then raise exception 'One or more selected seats are no longer available.'; end if;
  return new;
end;
$$;

drop trigger if exists rides_bus_reservation_conflicts on public.rides;
create trigger rides_bus_reservation_conflicts before insert or update on public.rides
  for each row execute function public.prevent_bus_reservation_conflicts();

insert into public.bus_companies (name) values
  ('YY Coaches'), ('Nile Star'), ('Nile Coach'), ('Gaagaa Coaches'),
  ('Baby Coach'), ('KK Travelers'), ('Zawadi Coaches'), ('Friends Bus')
on conflict (name) do nothing;

-- Editable starter schedules for the Arua–Kampala corridor. Confirm each
-- operator's actual schedules and classes before production launch.
insert into public.bus_schedules (company_id, departure_time, arrival_time, duration_minutes, service_class)
select c.id, s.departure_time, s.arrival_time, s.duration_minutes, s.service_class
from (values
  ('YY Coaches', time '06:00', time '14:00', 480, 'ordinary'),
  ('YY Coaches', time '12:00', time '20:00', 480, 'ordinary'),
  ('Nile Star', time '07:00', time '15:00', 480, 'ordinary'),
  ('Nile Star', time '08:00', time '16:00', 480, 'ordinary'),
  ('Nile Star', time '13:00', time '21:00', 480, 'executive'),
  ('Nile Star', time '16:00', time '00:00', 480, 'executive'),
  ('Nile Star', time '17:00', time '01:00', 480, 'ordinary')
) as s(company_name, departure_time, arrival_time, duration_minutes, service_class)
join public.bus_companies c on c.name = s.company_name
on conflict (company_id, origin, destination, departure_time, service_class) do nothing;

alter table public.bus_companies enable row level security;
alter table public.bus_schedules enable row level security;
drop policy if exists "authenticated users can read bus companies" on public.bus_companies;
create policy "authenticated users can read bus companies" on public.bus_companies for select to authenticated using (true);
drop policy if exists "authenticated users can read bus schedules" on public.bus_schedules;
create policy "authenticated users can read bus schedules" on public.bus_schedules for select to authenticated using (true);
