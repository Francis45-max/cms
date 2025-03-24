
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

    -- Check if container went through customs and add 4 additional free days
    IF v_customs_status = 'Yes' THEN
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
/

-----TEST CASES

SET SERVEROUTPUT ON;
DECLARE
    v_detention_days NUMBER;
BEGIN
    -- Test Case 1: No detention
    v_detention_days := Calculate_Detention_Charges('CONT123', DATE '2025-03-01', DATE '2025-03-10');
    DBMS_OUTPUT.PUT_LINE('Test Case 1 - Expected: 0, Got: ' || v_detention_days);

    -- Test Case 2: Detention applies
    v_detention_days := Calculate_Detention_Charges('CONT124', DATE '2025-03-01', DATE '2025-03-15');
    DBMS_OUTPUT.PUT_LINE('Test Case 2 - Expected: 5, Got: ' || v_detention_days);

    -- Test Case 3: Customs clearance adds extra days
    v_detention_days := Calculate_Detention_Charges('CONT125', DATE '2025-03-01', DATE '2025-03-15');
    DBMS_OUTPUT.PUT_LINE('Test Case 3 - Expected: 0, Got: ' || v_detention_days);

    -- Test Case 4: Customs clearance applied but still detained
    v_detention_days := Calculate_Detention_Charges('CONT126', DATE '2025-03-01', DATE '2025-03-20');
    DBMS_OUTPUT.PUT_LINE('Test Case 4 - Expected: 3, Got: ' || v_detention_days);

    -- Test Case 5: Port closure extends free time
    v_detention_days := Calculate_Detention_Charges('CONT127', DATE '2025-03-01', DATE '2025-03-15');
    DBMS_OUTPUT.PUT_LINE('Test Case 5 - Expected: 0, Got: ' || v_detention_days);

    -- Test Case 6: Invalid container (should raise an error)
    BEGIN
        v_detention_days := Calculate_Detention_Charges('INVALID', DATE '2025-03-01', DATE '2025-03-15');
        DBMS_OUTPUT.PUT_LINE('Test Case 6 - Expected: Error, Got: ' || v_detention_days);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Test Case 6 - Expected Error -20001, Got: ' || SQLERRM);
    END;

END;
/

---Test Case Table

Test Case Table
Test Case ID	Container Number  Gate Out Date	Gate In Date	Expected Detention	Description
TC1	         CONT123	   01-MAR-2025	10-MAR-2025	0	              Gate in within the free time, no detention.
TC2	         CONT124	   01-MAR-2025	15-MAR-2025	5	              Free time expired, detention applies.
TC3	         CONT125	   01-MAR-2025	15-MAR-2025	0	             Customs clearance adds 4 days, avoiding detention.
TC4	         CONT126	   01-MAR-2025	20-MAR-2025	3	              Customs clearance applied, but still detained after extra days.
TC5	         CONT127	   01-MAR-2025	15-MAR-2025	0	              Port closure days extend the free time, avoiding detention.
TC6	         INVALID	   01-MAR-2025	15-MAR-2025	Error -20001	           Container not found in the database.


