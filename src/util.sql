\if :{?shadow__util_sql}
\else
\set shadow__util_sql true

create function shadow_.is_schema(
    schema_name name
)
    returns boolean
    language sql
    security definer
    stable
as $$
    select exists(
        select from pg_namespace
        where nspname = schema_name
    )
$$;


create function shadow_.is_table(
    schema_name name,
    table_name name
)
    returns boolean
    language sql
    security definer
    stable
as $$
    select exists (
        select from pg_catalog.pg_tables
        where schemaname = schema_name
        and tablename = table_name
    )
$$;

create function shadow_.is_table(
    name_ name
)
    returns boolean
    language sql
    security definer
    stable
as $$
    select shadow_.is_table(n[1], n[2])
    from (select parse_ident(name_) n) n
$$;


create function shadow_.is_inherited (
    schema_name name,
    table_name name
)
    returns boolean
    language sql
    security definer
    stable
as $$
    select exists (
        select from pg_catalog.pg_inherits
        where inhparent = to_regclass(format('%I.%I', schema_name, table_name))
        and inhrelid = to_regclass(format('%I.%I', schema_name || '_', table_name))
    )
$$;

create function shadow_.is_inherited(
    name_ name
)
    returns boolean
    language sql
    security definer
    stable
as $$
    select shadow_.is_inherited(n[1], n[2])
    from (select parse_ident(name_) n) n
$$;


\endif
