
---Procedure to Calculate Bulk Detention Charges

CREATE OR REPLACE PROCEDURE Calculate_Bulk_Detention_Charges IS
    -- Define a record type to hold container details
    TYPE ContainerRecord IS RECORD (
        container_number Container.container_number%TYPE,
        gate_out_date Container.gate_out_date%TYPE,
        gate_in_date Container.gate_in_date%TYPE,
        customs_status Container.customs_status%TYPE,
        location_id Container.location_id%TYPE, -- Use location_id instead of activity_location
        free_time ServiceContract.free_time%TYPE
    );

    -- Define a table type to hold multiple container records
    TYPE ContainerTable IS TABLE OF ContainerRecord;

    -- Declare a variable to hold bulk container data
    v_containers ContainerTable;

    -- Variables for detention calculation
    v_last_free_day DATE;
    v_detention_days NUMBER;
    v_port_closure_dates DATE;
BEGIN
    -- Fetch all container details NUMBERo the bulk collection
    SELECT c.container_number, c.gate_out_date, c.gate_in_date, c.customs_status, c.location_id, sc.free_time
    BULK COLLECT NUMBERO v_containers
    FROM Container c
    JOIN ServiceContract sc ON c.service_contract_id = sc.service_contract_id
    WHERE c.gate_out_date IS NOT NULL AND c.gate_in_date IS NOT NULL;

    -- Process each container in the bulk collection
    FOR i IN 1..v_containers.COUNT LOOP
        -- Initialize variables for each container
        v_last_free_day := v_containers(i).gate_out_date + v_containers(i).free_time;
        v_detention_days := 0;

        -- Check if container went through customs
        IF v_containers(i).customs_status = 'Yes' THEN
            -- Add 4 additional free days, excluding weekends and port closure dates
            FOR j IN 1..4 LOOP
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
                        WHERE location_id = v_containers(i).location_id -- Use location_id instead of activity_location
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
        IF v_containers(i).gate_in_date > v_last_free_day THEN
            v_detention_days := v_containers(i).gate_in_date - v_last_free_day;
        END IF;

        -- Output the result (or store it in a table, if needed)
        DBMS_OUTPUT.PUT_LINE(
            'Container: ' || v_containers(i).container_number ||
            ', Customs Status: ' || v_containers(i).customs_status ||
            ', Location ID: ' || v_containers(i).location_id ||
            ', Detention Days: ' || v_detention_days
        );
    END LOOP;
END Calculate_Bulk_Detention_Charges;
/