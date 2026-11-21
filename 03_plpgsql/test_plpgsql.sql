BEGIN;
DO $$
DECLARE
    person bigint;
    a bigint;
    b bigint;
    foreign_account bigint;
    scratch bigint;
    patient_a bigint;
    patient_b bigint;
    doctor_a bigint;
    doctor_b bigint;
    t timestamptz := '2024-01-01 10:00:00+00';
BEGIN
    INSERT INTO fintech.currency VALUES ('USD'), ('EUR') ON CONFLICT DO NOTHING;
    INSERT INTO fintech.customer (email, full_name)
    VALUES ('test-' || gen_random_uuid() || '@example.test', 'Cliente de prueba')
    RETURNING customer_id INTO person;

    INSERT INTO fintech.account (customer_id, currency_code, balance)
    VALUES (person, 'USD', 100) RETURNING account_id INTO a;
    INSERT INTO fintech.account (customer_id, currency_code, balance)
    VALUES (person, 'USD', 25) RETURNING account_id INTO b;
    INSERT INTO fintech.account (customer_id, currency_code)
    VALUES (person, 'EUR') RETURNING account_id INTO foreign_account;
    INSERT INTO fintech.account (customer_id, currency_code)
    VALUES (person, 'USD') RETURNING account_id INTO scratch;
    DELETE FROM fintech.account WHERE account_id = scratch;

    CALL fintech.post_transfer(a, b, 40);
    UPDATE fintech.account SET balance = balance WHERE account_id = a;
    BEGIN
        CALL fintech.post_transfer(a, b, 100);
        RAISE EXCEPTION 'Se aceptó un sobregiro';
    EXCEPTION WHEN check_violation THEN NULL;
    END;
    BEGIN
        CALL fintech.post_transfer(a, foreign_account, 1);
        RAISE EXCEPTION 'Se aceptaron monedas distintas';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        CALL fintech.post_transfer(a, b, 0.001);
        RAISE EXCEPTION 'Se aceptó una fracción de centavo';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;
    BEGIN
        CALL fintech.post_transfer(a, -1, 1);
        RAISE EXCEPTION 'Se aceptó una cuenta inexistente';
    EXCEPTION WHEN foreign_key_violation THEN NULL;
    END;

    IF (SELECT balance FROM fintech.account WHERE account_id = a) IS DISTINCT FROM 60
       OR (SELECT balance FROM fintech.account WHERE account_id = b) IS DISTINCT FROM 65
       OR (SELECT count(*) FROM fintech.transfer WHERE source_id = a) <> 1
       OR NOT EXISTS (SELECT FROM fintech.transfer WHERE source_id = a AND destination_id = b AND amount = 40) THEN
        RAISE EXCEPTION 'Saldos o registro de transferencia incorrectos';
    END IF;
    IF (SELECT count(*) FROM audit.row_event
        WHERE row_key = jsonb_build_object('account_id', a)) <> 2
       OR NOT EXISTS (SELECT FROM audit.row_event
           WHERE row_key = jsonb_build_object('account_id', a) AND operation = 'UPDATE'
             AND changes = '{"balance":{"old":100,"new":60}}')
       OR NOT EXISTS (SELECT FROM audit.row_event
           WHERE row_key = jsonb_build_object('account_id', scratch) AND operation = 'INSERT'
             AND changes @> '{"balance":{"old":null,"new":0}}')
       OR NOT EXISTS (SELECT FROM audit.row_event
           WHERE row_key = jsonb_build_object('account_id', scratch) AND operation = 'DELETE'
             AND changes @> '{"balance":{"old":0,"new":null}}') THEN
        RAISE EXCEPTION 'Auditoría incorrecta';
    END IF;

    INSERT INTO clinic.patient (full_name) VALUES ('Paciente A') RETURNING patient_id INTO patient_a;
    INSERT INTO clinic.patient (full_name) VALUES ('Paciente B') RETURNING patient_id INTO patient_b;
    INSERT INTO clinic.clinician (full_name) VALUES ('Profesional A') RETURNING clinician_id INTO doctor_a;
    INSERT INTO clinic.clinician (full_name) VALUES ('Profesional B') RETURNING clinician_id INTO doctor_b;

    INSERT INTO clinic.appointment (patient_id, clinician_id, starts_at, ends_at, cancelled_at)
    VALUES (patient_a, doctor_a, t, t + interval '1 hour', NULL),
           (patient_a, doctor_a, t + interval '1 hour', t + interval '2 hours', NULL),
           (patient_a, doctor_a, t, t + interval '1 hour', t);
    BEGIN
        INSERT INTO clinic.appointment (patient_id, clinician_id, starts_at, ends_at)
        VALUES (patient_b, doctor_a, t, t + interval '1 hour');
        RAISE EXCEPTION 'Se aceptó un choque del profesional';
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
    BEGIN
        INSERT INTO clinic.appointment (patient_id, clinician_id, starts_at, ends_at)
        VALUES (patient_a, doctor_b, t, t + interval '1 hour');
        RAISE EXCEPTION 'Se aceptó un choque del paciente';
    EXCEPTION WHEN exclusion_violation THEN NULL;
    END;
END;
$$;
ROLLBACK;
