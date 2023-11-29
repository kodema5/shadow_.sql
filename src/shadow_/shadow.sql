\if :{?shadow__shadow_sql}
\else
\set shadow__shadow_sql true

\ir util.sql
\ir on_insert.sql

create procedure shadow_.shadow (
    schema_name name,
    table_name name,
    is_set boolean default true
)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
declare
    schema_ name = schema_name || '_';
    table_ name = table_name;
    parent name = format('%I.%I', schema_name, table_name);
    child name = format('%I.%I', schema_, table_);
begin
    -- add shadow
    if is_set
    then

        -- add shadow trigger
        call on_insert(parent);

        -- ensure schema
        if not is_schema(schema_)
        then
            execute format('create schema if not exists %I', schema_);
        end if;

        -- ensure shadow table
        -- if not is_table( schema_, table_ )
        if not is_table( child )
        then
            execute format('create table %s (like %s including all) inherits (%2$s)',
                child,
                parent);
        end if;

        -- ensure inheritance
        if not is_inherited(parent)
        then
            execute format('alter table %s inherit %s',
                child,
                parent);
        end if;


    -- detach shadow
    elsif is_inherited(parent)
    then

        -- remove inheritance
        execute format('alter table %s no inherit %s',
            child,
            parent);

        -- remove shadow trigger
        call on_insert(parent, false);
    end if;
end;
$$;


-- set/unset shadow to a schema
--
create procedure shadow_.shadow (
    schema_name name,
    is_set boolean default true
)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
declare
    r record;
begin
    -- for each table
    for r in (
        select tablename
        from pg_catalog.pg_tables
        where schemaname = schema_name)
    loop
        call shadow(schema_name, r.tablename, is_set);
    end loop;
end;
$$;


create procedure shadow_.attach(name_ name)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
begin
    call shadow(name_, true);
end;
$$;


create procedure shadow_.detach(name_ name)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
begin
    call shadow(name_, false);
end;
$$;

\if :{?test}
    create function tests.test_shadow_shadow()
        returns setof text
        language plpgsql
        set search_path = shadow_, public
    as $$
    begin
        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;
        create schema foo;
        create table foo.bar (a int, b text);
        call shadow('foo');
        insert into foo.bar values (1, 'a');

        return next ok(is_schema('foo_'), 'has shadow schema');
        return next ok(is_table('foo_.bar'), 'has shadow table');
        return next ok(is_inherited('foo.bar'), 'foo bar is inherited');
        return next ok(not exists(
            select from only foo.bar where a=1
        ), 'data not stored in parent table');
        return next ok(exists(
            select from only foo_.bar where a=1
        ), 'but in shadow table instead');


        call shadow('foo', false);
        return next ok(not is_inherited('foo.bar'), 'foo bar is no longer inherited');

        insert into foo.bar values (2, 'b');
        return next ok(exists(
            select from only foo.bar where a=2
        ) and not exists(
            select from only foo_.bar where a=2
        ), 'new data is stored in parent table only');


        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;
    end;
    $$;

\endif
\endif