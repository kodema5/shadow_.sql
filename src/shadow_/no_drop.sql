\if :{?shadow__protect_sql}
\else
\set shadow__protect_sql true

-- prevent dropping shadow schema_
--
create function shadow_.on_drop()
    returns event_trigger
    language plpgsql
    security definer
as $$
declare
    r record;
    f boolean;
begin
    for r in
        select *
        from pg_event_trigger_dropped_objects()
    loop
        if r.object_type='schema' and right(r.object_identity,1) = '_'
            or right(r.schema_name,1) = '_'
        then
            raise warning 'shadow_.no_drop % %',
                tg_tag,
                r.object_identity;

            raise exception 'shadow_.no_drop';
        end if;
    end loop;
end;
$$;


create procedure shadow_.no_drop (
    is_set boolean default true
)
    language plpgsql
    security definer
    set search_path = shadow_, public
as $$
begin
    drop event trigger if exists shadow_on_drop;

    if not is_set then return; end if;

    create event trigger shadow_on_drop
        on sql_drop
        execute function shadow_.on_drop();
end;
$$;


\if :{?test}

    create function tests.test_shadow_no_drop()
        returns setof text
        language plpgsql
        set search_path = shadow_, public
    as $$
    begin
        call no_drop(false);
        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;

        create schema foo;
        create table foo.bar (a int, b text);

        -- when no-drop and shadowed
        call no_drop(true);
        call shadow('foo');

        return next throws_ok('drop schema foo cascade', 'shadow_.no_drop');
        return next throws_ok('drop table foo_.bar cascade', 'shadow_.no_drop');
        return next ok(is_schema('foo')
            and is_schema('foo_')
            and is_table('foo_.bar')
        , 'foo drop was canceled when protected');

        -- when not shadowed
        call shadow('foo', false);
        drop schema if exists foo cascade;
        return next ok(
            not is_schema('foo')
            and is_schema('foo_')
        , 'foo is dropped, foo_ is kept');

        -- when not protected
        call no_drop(false);
        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;
        return next ok(
            not is_schema('foo')
            and not is_schema('foo_')
        , 'both foo and foo_ were dropped');

    end;
    $$;


\endif

\endif