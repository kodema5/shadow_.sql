\if :{?shadow__on_insert_sql}
\else
\set shadow__on_insert_sql true

\ir shadow.sql

-- moves data to shadow schema
--
create function shadow_.on_before_insert()
    returns trigger
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
begin
    -- ensure has shadow
    --
    call shadow(tg_table_schema, tg_table_name);

    -- insert data to shadow table
    --
    execute format('insert into %s select (%1$s %s).*',
        format('%I.%I', tg_table_schema || '_', tg_table_name),
        quote_literal(new));

    return null;

-- for upsert -- this however targets parent vs child table
-- exception
--     when unique_violation then
--         return new;

end;
$$;


create procedure shadow_.on_insert (
    schema_name name,
    table_name name,
    is_enable boolean default true
)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
begin
    execute format(
        case
        when is_enable then
            'create trigger shadow_on_before_insert_%I_%I '
            'before insert on %1$I.%2$I '
            'for each row '
            'execute function shadow_.on_before_insert()'
        else
            'drop trigger if exists shadow_on_before_insert_%I_%I '
            'on %1$I.%2$I'
        end,
        schema_name,
        table_name);
exception
    when duplicate_object then
        null;
end;
$$;

create procedure shadow_.on_insert (
    name_ name,
    is_enable boolean default true
)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
declare
    ns name[] = parse_ident(name_);
begin
    call on_insert(ns[1], ns[2], is_enable);
end;
$$;


\if :{?test}
    create function tests.test_shadow_on_insert()
        returns setof text
        language plpgsql
        set search_path = shadow_, public
    as $$

    begin
        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;
        create schema foo;
        create table foo.bar (a int primary key, b text);
        call on_insert('foo.bar');

        insert into foo.bar values (1, 'a');
        return next ok(exists (select from foo.bar where a=1 and b='a'), 'has row');
        return next ok(not exists (select from only foo.bar where a=1 and b='a'), 'should not be in foo');
        return next ok(exists (select from only foo_.bar where a=1 and b='a'), 'but in foo_');

        return next throws_ok('
            insert into foo.bar values (1, ''b'')
            on conflict (a)
            do update set b = excluded.b
        ');
        return next ok(
            NOT exists (select from foo.bar where a=1 and b='b'),
            'insert on conflict is NOT supported!');

        -- insert into foo.bar values (1, 'b')
        --     on conflict (a)
        --     do update set b = excluded.b;
        -- return next ok(not exists (select from only foo.bar where a=1 and b='b'), 'should not be in foo');
        -- return next ok(exists (select from only foo_.bar where a=1 and b='b'), 'but in foo_');

        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;
    end;
    $$;

\endif

\endif