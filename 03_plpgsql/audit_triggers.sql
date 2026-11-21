BEGIN;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE TABLE IF NOT EXISTS audit.row_event (
    event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    happened_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    actor name NOT NULL DEFAULT current_user,
    table_schema name NOT NULL,
    table_name name NOT NULL,
    operation text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    row_key jsonb NOT NULL,
    changes jsonb NOT NULL
);
CREATE OR REPLACE FUNCTION audit.capture_diff()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    before_row jsonb := CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) ELSE '{}'::jsonb END;
    after_row jsonb := CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) ELSE '{}'::jsonb END;
    diff jsonb;
    identity_column text;
    row_image jsonb := before_row || after_row;
    identity_values jsonb := '{}'::jsonb;
BEGIN
    IF TG_NARGS = 0 THEN
        RAISE EXCEPTION 'audit.capture_diff requiere columnas de identidad';
    END IF;
    FOREACH identity_column IN ARRAY TG_ARGV LOOP
        IF NOT row_image ? identity_column THEN
            RAISE EXCEPTION 'Columna de identidad inexistente: %', identity_column;
        END IF;
        identity_values := identity_values || jsonb_build_object(identity_column, row_image -> identity_column);
    END LOOP;

    SELECT jsonb_object_agg(k, jsonb_build_object('old', before_row -> k, 'new', after_row -> k))
    INTO diff
    FROM jsonb_object_keys(row_image) AS keys(k)
    WHERE (before_row -> k) IS DISTINCT FROM (after_row -> k);

    IF diff IS NOT NULL THEN
        INSERT INTO audit.row_event (table_schema, table_name, operation, row_key, changes)
        VALUES (TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, identity_values, diff);
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER account_audit
AFTER INSERT OR UPDATE OR DELETE ON fintech.account
FOR EACH ROW EXECUTE FUNCTION audit.capture_diff('account_id');
COMMIT;
