-- Run AFTER fast_ride_booking_setup.sql. No changes to fares or timetables.
-- Serialize reservations against the same schedule and check all passengers'
-- reservations privately, without exposing their profile or booking data.
begin;

create or replace function public.prevent_bus_reservation_conflicts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  schedule public.bus_schedules%rowtype;
  selected_seat text;
  seat_index integer;
begin
  if new.vehicle_type::text is distinct from 'bus'
      or new.status::text = 'cancelled' then
    return new;
  end if;

  -- Legacy bookings can still receive status updates. New bus bookings must
  -- always identify a specific schedule and travel date.
  if new.bus_schedule_id is null or new.travel_date is null then
    if TG_OP = 'INSERT' then
      raise exception 'Select a bus departure and travel date.';
    end if;
    return new;
  end if;

  select s.* into schedule from public.bus_schedules s
    where s.id = new.bus_schedule_id for update;
  if not found then raise exception 'The selected departure does not exist.'; end if;

  if TG_OP = 'INSERT' then
    if not schedule.is_active or not exists (
      select 1 from public.bus_companies c where c.id = schedule.company_id and c.is_active
    ) then raise exception 'This departure is no longer available.'; end if;
    if (new.travel_date + schedule.departure_time) <= (now() at time zone 'Africa/Kampala') then
      raise exception 'Choose a departure that has not left yet.';
    end if;
  end if;

  new.travel_class := schedule.service_class;
  if new.reservation_type = 'whole_bus' then
    new.seat_number := null;
    new.seat_numbers := null;
  elsif new.reservation_type = 'individual' then
    new.seat_numbers := coalesce(new.seat_numbers, array[new.seat_number]);
    if cardinality(new.seat_numbers) = 0 or array_position(new.seat_numbers, null) is not null then
      raise exception 'Select at least one valid seat.';
    end if;
    if cardinality(new.seat_numbers) <> (select count(distinct seat) from unnest(new.seat_numbers) seat) then
      raise exception 'A seat cannot be selected more than once.';
    end if;
    foreach selected_seat in array new.seat_numbers loop
      if selected_seat !~ '^([1-9]|1[0-9]|20)[ABCD]$' then
        raise exception 'Invalid seat selection.';
      end if;
      seat_index := (substring(selected_seat from '^[0-9]+')::integer - 1) * 4
        + strpos('ABCD', right(selected_seat, 1));
      if seat_index > schedule.total_seats then
        raise exception 'Selected seat exceeds this bus capacity.';
      end if;
    end loop;
    new.seat_number := new.seat_numbers[1];
    new.booking_details := jsonb_set(coalesce(new.booking_details, '{}'::jsonb),
      '{passenger_count}', to_jsonb(cardinality(new.seat_numbers)));
  else
    raise exception 'Choose seats or a whole-bus reservation.';
  end if;

  if exists (
    select 1 from public.rides r
    where r.bus_schedule_id = new.bus_schedule_id and r.travel_date = new.travel_date
      and r.id is distinct from new.id and r.status::text <> 'cancelled'
      and (new.reservation_type = 'whole_bus' or r.reservation_type = 'whole_bus'
        or coalesce(r.seat_numbers, array[r.seat_number]) && new.seat_numbers)
  ) then
    raise exception 'These seats or this bus are no longer available. Choose another reservation.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_bus_reservation_conflicts() from public, anon, authenticated;
drop trigger if exists rides_bus_reservation_conflicts on public.rides;
create trigger rides_bus_reservation_conflicts before insert or update on public.rides
  for each row execute function public.prevent_bus_reservation_conflicts();

grant select on public.bus_companies, public.bus_schedules to authenticated;
commit;
