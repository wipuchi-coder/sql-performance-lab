BEGIN;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA IF NOT EXISTS clinic;
CREATE TABLE IF NOT EXISTS clinic.patient (
    patient_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL
);
CREATE TABLE IF NOT EXISTS clinic.clinician (
    clinician_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL
);
CREATE TABLE IF NOT EXISTS clinic.appointment (
    appointment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id bigint NOT NULL REFERENCES clinic.patient,
    clinician_id bigint NOT NULL REFERENCES clinic.clinician,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    cancelled_at timestamptz,
    CHECK (isfinite(starts_at) AND isfinite(ends_at) AND starts_at < ends_at),
    EXCLUDE USING gist (clinician_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
        WHERE (cancelled_at IS NULL),
    EXCLUDE USING gist (patient_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
        WHERE (cancelled_at IS NULL)
);
CREATE INDEX IF NOT EXISTS appointment_patient_idx ON clinic.appointment (patient_id);
CREATE INDEX IF NOT EXISTS appointment_clinician_idx ON clinic.appointment (clinician_id);
COMMIT;
