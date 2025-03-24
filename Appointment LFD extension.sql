---Procedure to Extend Free Time Based On Appointment

CREATE OR REPLACE PROCEDURE Extend_Free_Time_Based_On_Appointment 
IS
    -- Cursor to fetch relevant records
    CURSOR cur_cont IS 
        SELECT sc.service_contract_id, sc.free_time, sc.new_lfd, t.appointment_status
        FROM ServiceContract sc
        JOIN Container c ON sc.service_contract_id = c.service_contract_id
        JOIN Terminal t ON c.location_id = t.location_id
        WHERE t.appointment_status LIKE 'unavailable for % days';

    -- Variables to store fetched values
    v_service_contract_id ServiceContract.service_contract_id%TYPE;
    v_free_time ServiceContract.free_time%TYPE;
    v_new_lfd ServiceContract.new_lfd%TYPE;
    v_appointment_status Terminal.appointment_status%TYPE;
    v_days_to_extend NUMBER;

BEGIN
    OPEN cur_cont;
    LOOP
        -- Fetch one row at a time
        FETCH cur_cont INTO v_service_contract_id, v_free_time, v_new_lfd, v_appointment_status;
        EXIT WHEN cur_cont%NOTFOUND;

        -- Extract number of unavailable days
        BEGIN
            v_days_to_extend := TO_NUMBER(REGEXP_SUBSTR(v_appointment_status, '\d+'));
        EXCEPTION
            WHEN OTHERS THEN 
                v_days_to_extend := NULL; -- Handle cases where extraction fails
        END;

        -- Compute new LFD (Last Free Day)
        v_new_lfd := 
            CASE 
                WHEN v_days_to_extend IS NOT NULL THEN v_free_time + v_days_to_extend
                ELSE v_free_time
            END;

        -- Update the ServiceContract table
        UPDATE ServiceContract 
        SET new_lfd = v_new_lfd
        WHERE service_contract_id = v_service_contract_id;

        -- Insert into audit log with correct data types
        INSERT INTO ContainerAuditLog (
            audit_timestamp, audit_action, affected_table, affected_record_id, 
            old_value, new_value, user_name, session_id
        ) 
        VALUES (
            SYSTIMESTAMP, 'UPDATE', 'ServiceContract', v_service_contract_id, 
            TO_CHAR(v_free_time), TO_CHAR(v_new_lfd), 
            USER, SYS_CONTEXT('USERENV', 'SESSIONID')
        );

        COMMIT;
    END LOOP;
    CLOSE cur_cont;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO ErrorLog (
            error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id
        ) VALUES (
            SYSTIMESTAMP, DBMS_UTILITY.FORMAT_ERROR_STACK, 'ServiceContract', 'N/A', 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID')
        );
        COMMIT;
END Extend_Free_Time_Based_On_Appointment;
/



-- Test Case for Extend_Free_Time_Based_On_Appointment Procedure

-- Step 1: Setup test data

-- Insert test data into ServiceContract
INSERT INTO ServiceContract (service_contract_id, free_time, new_lfd) 
VALUES (1, 10, NULL);

INSERT INTO ServiceContract (service_contract_id, free_time, new_lfd) 
VALUES (2, 5, NULL);

-- Insert test data into Container
INSERT INTO Container (container_id, service_contract_id, location_id) 
VALUES (100, 1, 10);

INSERT INTO Container (container_id, service_contract_id, location_id) 
VALUES (101, 2, 20);

-- Insert test data into Terminal with appointment statuses
INSERT INTO Terminal (location_id, appointment_status) 
VALUES (10, 'unavailable for 3 days');

INSERT INTO Terminal (location_id, appointment_status) 
VALUES (20, 'unavailable for 5 days');

COMMIT;

-- Step 2: Execute the procedure
BEGIN
    Extend_Free_Time_Based_On_Appointment;
END;
/

-- Step 3: Validate the results

-- Check if new_lfd is updated correctly
SELECT service_contract_id, free_time, new_lfd 
FROM ServiceContract
WHERE service_contract_id IN (1, 2);

-- Expected Output:
-- service_contract_id | free_time | new_lfd
-- --------------------|----------|--------
-- 1                  | 10       | 13  (10 + 3 days)
-- 2                  | 5        | 10  (5 + 5 days)

-- Check if audit logs are created
SELECT * FROM ContainerAuditLog 
WHERE affected_table = 'ServiceContract';

-- Expected Output: 
-- Audit logs should be present showing changes in `new_lfd`

-- Step 4: Cleanup test data after validation
DELETE FROM ContainerAuditLog WHERE affected_table = 'ServiceContract';
DELETE FROM Terminal WHERE location_id IN (10, 20);
DELETE FROM Container WHERE container_id IN (100, 101);
DELETE FROM ServiceContract WHERE service_contract_id IN (1, 2);
COMMIT;
