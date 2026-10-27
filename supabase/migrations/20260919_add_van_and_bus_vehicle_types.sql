-- FastRide: allow the complete vehicle list used by the mobile app.
-- Safe to run more than once in the Supabase SQL Editor.

begin;

do $migration$
declare
  target_table text;
  existing_constraint record;
  column_type record;
  constraint_name text;
begin
  foreach target_table in array array['rides', 'deliveries']
  loop
    -- Skip a table when it has not been created in this environment yet.
    if to_regclass(format('public.%I', target_table)) is null then
      raise notice 'Skipping public.% because it does not exist.', target_table;
      continue;
    end if;

    -- Fail with a useful message instead of silently doing nothing when the
    -- table exists but its expected column does not.
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = target_table
        and column_name = 'vehicle_type'
    ) then
      raise exception 'public.% has no vehicle_type column.', target_table;
    end if;

    -- Some projects model vehicle_type as a PostgreSQL enum instead of text.
    -- Extend that enum directly and leave its built-in validation in charge.
    select type_namespace.nspname as schema_name, type_info.typname, type_info.typtype
    into column_type
    from pg_attribute attribute_info
    join pg_class table_info on table_info.oid = attribute_info.attrelid
    join pg_namespace table_namespace on table_namespace.oid = table_info.relnamespace
    join pg_type type_info on type_info.oid = attribute_info.atttypid
    join pg_namespace type_namespace on type_namespace.oid = type_info.typnamespace
    where table_namespace.nspname = 'public'
      and table_info.relname = target_table
      and attribute_info.attname = 'vehicle_type'
      and not attribute_info.attisdropped;

    if column_type.typtype = 'e' then
      execute format(
        'alter type %I.%I add value if not exists %L',
        column_type.schema_name,
        column_type.typname,
        'van'
      );
      execute format(
        'alter type %I.%I add value if not exists %L',
        column_type.schema_name,
        column_type.typname,
        'bus'
      );
      raise notice 'Extended enum %.% for public.%.vehicle_type.',
        column_type.schema_name,
        column_type.typname,
        target_table;
      continue;
    end if;

    -- Constraint names vary depending on how the original tables were made.
    -- Remove only CHECK constraints whose expression uses vehicle_type.
    for existing_constraint in
      select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = target_table
        and c.contype = 'c'
        and pg_get_constraintdef(c.oid) ilike '%vehicle_type%'
    loop
      execute format(
        'alter table public.%I drop constraint %I',
        target_table,
        existing_constraint.conname
      );
    end loop;

    constraint_name := target_table || '_vehicle_type_check';
    execute format(
      'alter table public.%I add constraint %I check '
      || '(vehicle_type is null or vehicle_type in '
      || '(''motorcycle'', ''tuktuk'', ''car'', ''bicycle'', ''van'', ''bus''))',
      target_table,
      constraint_name
    );
  end loop;
end
$migration$;

commit;

-- Verify the values now accepted by each table.
select
  t.relname as table_name,
  c.conname as constraint_name,
  pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname in ('rides', 'deliveries')
  and c.contype = 'c'
  and pg_get_constraintdef(c.oid) ilike '%vehicle_type%'
order by t.relname;
