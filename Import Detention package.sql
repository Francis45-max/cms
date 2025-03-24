CREATE OR REPLACE PACKAGE DETENTION_PKG IS
    -- Function to calculate detention charges for a single container
    FUNCTION Calculate_Detention_Charges(
        p_container_number IN VARCHAR2,
        p_gate_out_date IN DATE,
        p_gate_in_date IN DATE
    ) RETURN NUMBER;

    -- Procedure to convert detention charges to customer's region currency
    PROCEDURE Convert_To_Customer_Currency_Proc(
        p_container_number IN VARCHAR2,
        p_customer_id IN VARCHAR2,
        p_converted_charges OUT NUMBER
    );
END DETENTION_PKG;
/

CREATE OR REPLACE PACKAGE BODY DETENTION_PKG IS
    -- Function to calculate detention charges for a single container
    FUNCTION Calculate_Detention_Charges(
        p_container_number IN VARCHAR2,
        p_gate_out_date IN DATE,
        p_gate_in_date IN DATE
    ) RETURN NUMBER IS
        v_free_time NUMBER;
        v_last_free_day DATE;
        v_detention_days NUMBER := 0;
        v_customs_status VARCHAR2(3);
        v_location_id NUMBER;
        v_port_closure_count NUMBER;
    BEGIN
        -- Get free time, customs status, and location_id for the container
        BEGIN
            SELECT sc.free_time, c.customs_status, c.location_id
            INTO v_free_time, v_customs_status, v_location_id
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
                WHILE TO_CHAR(v_last_free_day, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') IN ('SAT', 'SUN') LOOP
                    v_last_free_day := v_last_free_day + 1;
                END LOOP;

                -- Skip port closure dates
                LOOP
                    SELECT COUNT(*) INTO v_port_closure_count
                    FROM Terminal
                    WHERE location_id = v_location_id
                      AND port_closure_dates = v_last_free_day;

                    EXIT WHEN v_port_closure_count = 0; -- No closure, exit loop
                    v_last_free_day := v_last_free_day + 1; -- If closed, move to next day
                END LOOP;
            END LOOP;
        END IF;

        -- Calculate detention days
        IF p_gate_in_date > v_last_free_day THEN
            v_detention_days := p_gate_in_date - v_last_free_day;
        END IF;

        RETURN NVL(v_detention_days, 0); -- Ensure a value is always returned
    END Calculate_Detention_Charges;

    -- Procedure to convert detention charges to customer's region currency
    PROCEDURE Convert_To_Customer_Currency_Proc(
        p_container_number IN VARCHAR2,
        p_customer_id IN VARCHAR2,
        p_converted_charges OUT NUMBER
    ) IS
        v_detention_days NUMBER;
        v_activity_currency VARCHAR2(50);
        v_billed_currency VARCHAR2(50);
        v_conversion_rate NUMBER(10,2);
        v_region_id NUMBER;
        v_gate_out_date DATE;
        v_gate_in_date DATE;
    BEGIN
        -- Fetch gate_out_date and gate_in_date for the container
        BEGIN
            SELECT c.gate_out_date, c.gate_in_date
            INTO v_gate_out_date, v_gate_in_date
            FROM Container c
            WHERE c.container_number = p_container_number;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002, 'Container not found.');
        END;

        -- Calculate detention days
        v_detention_days := Calculate_Detention_Charges(p_container_number, v_gate_out_date, v_gate_in_date);

        -- Fetch region_id for the customer
        BEGIN
            SELECT region_id INTO v_region_id
            FROM Customer
            WHERE cust_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Customer not found.');
        END;

        -- Fetch currency details for the customer's region
        BEGIN
            SELECT activity_currency, billed_currency, conversion_rate
            INTO v_activity_currency, v_billed_currency, v_conversion_rate
            FROM Currency
            WHERE region_id = v_region_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'Currency details not found for the customer.');
        END;

        -- Calculate detention charges in the billed currency
        p_converted_charges := v_detention_days * v_conversion_rate;
    END Convert_To_Customer_Currency_Proc;
END DETENTION_PKG;
/
