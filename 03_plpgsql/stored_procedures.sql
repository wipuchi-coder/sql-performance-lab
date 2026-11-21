CREATE OR REPLACE PROCEDURE fintech.post_transfer(source_account bigint, destination_account bigint, requested_amount numeric)
LANGUAGE plpgsql
AS $$
DECLARE
    source_row fintech.account%ROWTYPE;
    destination_row fintech.account%ROWTYPE;
    locked_account fintech.account%ROWTYPE;
BEGIN
    IF source_account IS NULL OR destination_account IS NULL OR source_account = destination_account THEN
        RAISE EXCEPTION 'Se requieren dos cuentas distintas' USING ERRCODE = '22023';
    END IF;
    IF requested_amount IS NULL OR requested_amount <= 0
       OR requested_amount >= 10000000000000000
       OR requested_amount <> round(requested_amount, 2) THEN
        RAISE EXCEPTION 'Importe inválido' USING ERRCODE = '22023';
    END IF;

    -- NO KEY UPDATE protege el saldo y es compatible con los bloqueos de FK.
    FOR locked_account IN
        SELECT * FROM fintech.account
        WHERE account_id IN (source_account, destination_account)
        ORDER BY account_id FOR NO KEY UPDATE
    LOOP
        IF locked_account.account_id = source_account THEN
            source_row := locked_account;
        ELSE
            destination_row := locked_account;
        END IF;
    END LOOP;

    IF source_row.account_id IS NULL OR destination_row.account_id IS NULL THEN
        RAISE EXCEPTION 'Cuenta inexistente' USING ERRCODE = '23503';
    END IF;
    IF source_row.currency_code <> destination_row.currency_code THEN
        RAISE EXCEPTION 'Las monedas deben coincidir' USING ERRCODE = '22023';
    END IF;
    IF source_row.balance < requested_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente' USING ERRCODE = '23514';
    END IF;

    UPDATE fintech.account
    SET balance = balance + CASE WHEN account_id = source_account THEN -requested_amount ELSE requested_amount END
    WHERE account_id IN (source_account, destination_account);

    INSERT INTO fintech.transfer (source_id, destination_id, amount)
    VALUES (source_account, destination_account, requested_amount);
END;
$$;
