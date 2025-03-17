
-- Function to calculate detention charges for a single container


CREATE OR REPLACE FUNCTION Calculate_Detention_Charges(
        p_container_number IN VARCHAR2,
        p_gate_out_date IN DATE,
        p_gate_in_date IN DATE
    ) RETURN NUMBER IS
        v_free_time NUMBER;
        v_last_free_day DATE;
        v_detention_days NUMBER := 0;
        v_customs_status VARCHAR2(3);
        v_location_id NUMBER;
        v_port_closure_dates DATE;
    BEGIN
        -- Get free time, customs status, and location_id for the container
        BEGIN
            SELECT sc.free_time, c.customs_status, c.location_id
            NUMBERO v_free_time, v_customs_status, v_location_id
            FROM Container c
            JOIN ServiceContract sc ON c.service_contract_id = sc.service_contract_id
            WHERE c.container_number = p_container_number;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Container not found or missing data.');
        END;

        -- Calculate last free day
        v_last_free_day := p_gate_out_date + v_free_time;

        -- Check if container went through customs
        IF v_customs_status = 'Yes' THEN
            -- Add 4 additional free days, excluding weekends and port closure dates
            FOR i IN 1..4 LOOP
                v_last_free_day := v_last_free_day + 1;

                -- Skip weekends (Saturday and Sunday)
                WHILE TO_CHAR(v_last_free_day, 'DY') IN ('SAT', 'SUN') LOOP
                    v_last_free_day := v_last_free_day + 1;
                END LOOP;

                -- Skip port closure dates (from Terminal table)
                LOOP
                    BEGIN
                        -- Check if the current v_last_free_day is a port closure date
                        SELECT port_closure_dates NUMBERO v_port_closure_dates
                        FROM Terminal
                        WHERE location_id = v_location_id
                          AND port_closure_dates = v_last_free_day;

                        -- If port closure date is found, skip it by incrementing v_last_free_day
                        v_last_free_day := v_last_free_day + 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            EXIT; -- No port closure, exit the loop
                    END;
                END LOOP;
            END LOOP;
        END IF;

        -- Calculate detention days
        IF p_gate_in_date > v_last_free_day THEN
            v_detention_days := p_gate_in_date - v_last_free_day;
        END IF;

        RETURN v_detention_days;
    END Calculate_Detention_Charges;
