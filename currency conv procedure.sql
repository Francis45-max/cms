

--Procedure to convert detention charges to customer's region currency

CREATE OR REPLACE PROCEDURE Convert_To_Customer_Currency_Proc(
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
    -- Fetch container, customer, and currency details in a single query for efficiency
    BEGIN
        SELECT c.gate_out_date, c.gate_in_date, cu.region_id, curr.activity_currency, 
               curr.billed_currency, curr.conversion_rate
        INTO v_gate_out_date, v_gate_in_date, v_region_id, v_activity_currency, 
             v_billed_currency, v_conversion_rate
        FROM Container c
        JOIN Customer cu ON c.customer_id = cu.cust_id
        JOIN Currency curr ON cu.region_id = curr.region_id
        WHERE c.container_number = p_container_number
          AND cu.cust_id = p_customer_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Container, customer, or currency details not found.');
    END;

    -- Calculate detention days using the external function/procedure
    v_detention_days := Calculate_Detention_Charges(p_container_number, v_gate_out_date, v_gate_in_date);
    
    -- Ensure detention days is not NULL
    IF v_detention_days IS NULL THEN
        v_detention_days := 0;
    END IF;

    -- Calculate detention charges in the billed currency
    p_converted_charges := v_detention_days * v_conversion_rate;

    DBMS_OUTPUT.PUT_LINE('Container: ' || p_container_number || ', Customer ID: ' || p_customer_id ||
                         ', Detention Days: ' || v_detention_days || ', Converted Charges: ' || p_converted_charges);
END Convert_To_Customer_Currency_Proc;
/



----Test case

DECLARE
    v_converted_charges NUMBER;
BEGIN
    Convert_To_Customer_Currency_Proc(
        p_container_number => 'CONT123',  -- Replace with an actual container number
        p_customer_id => 'CUST456',      -- Replace with an actual customer ID
        p_converted_charges => v_converted_charges
    );

    -- Display the converted detention charges
    DBMS_OUTPUT.PUT_LINE('Converted Detention Charges: ' || v_converted_charges);
END;
/
---Inserting Sample data

-- Insert into ServiceContract table
INSERT INTO ServiceContract (service_contract_id, free_time)
VALUES (101, 5); -- Assuming 5 days free time

-- Insert into Container table
INSERT INTO Container (container_number, service_contract_id, gate_out_date, gate_in_date, customs_status, location_id, customer_id)
VALUES ('CONT123', 101, SYSDATE - 15, SYSDATE, 'No', 1, 'CUST456'); -- 15 days ago gate out, returned today

-- Insert into Customer table
INSERT INTO Customer (cust_id, customer_name, region_id)
VALUES ('CUST456', 'Test Customer', 1);

-- Insert into Currency table
INSERT INTO Currency (region_id, activity_currency, billed_currency, conversion_rate)
VALUES (1, 'USD', 'EUR', 0.85); -- USD to EUR conversion rate


----
Final Result: 8.5 EUR (Converted Detention Charges) 
