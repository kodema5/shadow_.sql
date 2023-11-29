\if :{?shadow__sql}
\else
\set shadow__sql true

drop schema if exists shadow_ cascade;
create schema shadow_;

\ir shadow_/util.sql
\ir shadow_/on_insert.sql
\ir shadow_/shadow.sql
\ir shadow_/no_drop.sql

\if :{?test}

    create function tests.test_dev_cycle()
        returns setof text
        language plpgsql
        set search_path = shadow_, public
    as $$
    begin
        -- disallow drop of schema_
        call shadow_.no_drop();

        -- prior "drop schema .. cascade"
        --
        call shadow_.detach('foo');
        call tests.dev_scripts();
        call shadow_.attach('foo');


        return next ok(shadow_.is_schema('foo_'), 'has shadow schema');
        return next ok(foo.count() = 1, 'has script defined entry');

        insert into foo.bar values (2, 'user entry');
        return next ok(foo.count() = 2, 'has dynamic entries');

        -- suppoed code changed
        --
        call shadow_.detach('foo');
        call tests.dev_scripts();
        call shadow_.attach('foo');

        return next ok(foo.count() = 2, 'still has previous entries');

        -- optionally re-allow drop of schema_
        -- for sysadmin to really drop data
        call shadow_.no_drop(false);
        drop schema if exists foo cascade;
        drop schema if exists foo_ cascade;
    end;
    $$;


    -- an example
    --
    create procedure tests.dev_scripts()
        language plpgsql
    as $$
    begin
        drop schema if exists foo cascade;
        create schema foo;
        create table foo.bar (a int, b text);
        insert into foo.bar values (1, 'static entry');

        create function foo.count () returns int language sql as $fun$
            select count(1) from foo.bar;
        $fun$;


    end;
    $$;
\endif

\endif
