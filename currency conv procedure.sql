

--Procedure to convert detention charges to customer's region currency

CREATE OR REPLACE PROCEDURE Convert_To_Customer_Currency_Proc(
        p_container_number IN VARCHAR2,
        p_customer_id IN VARCHAR2,
        p_converted_charges OUT NUMBER
    ) IS
        v_detention_days NUMBER;
        v_activity_currency VARCHAR2(50);
        v_billed_currency VARCHAR2(50);
        v_conversion_rate DECIMAL(10, 2);
        v_region_id NUMBER;
        v_gate_out_date DATE; -- Declare v_gate_out_date
        v_gate_in_date DATE;  -- Declare v_gate_in_date
    BEGIN
        -- Fetch gate_out_date and gate_in_date for the container
        BEGIN
            SELECT c.gate_out_date, c.gate_in_date
            NUMBERO v_gate_out_date, v_gate_in_date
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
            SELECT region_id NUMBERO v_region_id
            FROM Customer
            WHERE cust_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 'Customer not found.');
        END;

        -- Fetch currency details for the customer's region
        BEGIN
            SELECT activity_currency, billed_currency, conversion_rate
            NUMBERO v_activity_currency, v_billed_currency, v_conversion_rate
            FROM Currency
            WHERE region_id = v_region_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20004, 'Currency details not found for the customer.');
        END;

        -- Calculate detention charges in the billed currency
        p_converted_charges := v_detention_days * v_conversion_rate;
    END Convert_To_Customer_Currency_Proc;