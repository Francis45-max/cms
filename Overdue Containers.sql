CREATE OR REPLACE PROCEDURE Send_Overdue_Notifications IS
    -- Cursor to fetch overdue containers
    CURSOR overdue_containers IS
        SELECT c.container_number, c.customer_id, cu.customer_name, cu.region,
               c.gate_out_date, c.gate_in_date, c.customs_status,
               (c.gate_in_date - (c.gate_out_date + sc.free_time)) AS overdue_days,
               cu.email, cu.phone
        FROM Container c
        JOIN Customer cu ON c.customer_id = cu.cust_id
        JOIN ServiceContract sc ON c.service_contract_id = sc.service_contract_id
        WHERE c.gate_in_date > (c.gate_out_date + sc.free_time)
          AND c.customs_status = 'No'; -- Only for non-customs cleared containers

    -- Variables
    v_message VARCHAR2(1000);
    v_error_message VARCHAR2(1000);
    v_email VARCHAR2(100);
    v_phone VARCHAR2(20);
    v_processed NUMBER := 0;

BEGIN
    -- Process overdue containers
    FOR container IN overdue_containers LOOP
        BEGIN
            v_processed := v_processed + 1; -- Count processed containers
            
            -- Construct the notification message
            v_message := 'Dear ' || container.customer_name || ',' || CHR(10) ||
                         'Your container ' || container.container_number || ' is overdue by ' ||
                         container.overdue_days || ' days.' || CHR(10) ||
                         'Please take necessary action to avoid additional charges.' || CHR(10) ||
                         'Thank you,' || CHR(10) ||
                         'Logistics Management Team';

            -- Assign email & phone from cursor
            v_email := container.email;
            v_phone := container.phone;

            -- Send email (assuming UTL_MAIL is configured)
            BEGIN
                UTL_MAIL.SEND(
                    sender => 'esther@tjx.com',
                    recipients => v_email,
                    subject => 'Overdue Container Notification',
                    message => v_message
                );
                DBMS_OUTPUT.PUT_LINE('Email sent to ' || v_email || ' for container ' || container.container_number);
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := 'Failed to send email to ' || v_email || ': ' || SQLERRM;
                    INSERT INTO ErrorLog (error_id, error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id)
                    VALUES (error_log_seq.NEXTVAL, SYSTIMESTAMP, v_error_message, 'Container', container.container_number, 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
                    DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
            END;

        EXCEPTION
            WHEN OTHERS THEN
                v_error_message := 'Unexpected error for container ' || container.container_number || ': ' || SQLERRM;
                INSERT INTO ErrorLog (error_id, error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id)
                VALUES (error_log_seq.NEXTVAL, SYSTIMESTAMP, v_error_message, 'Container', container.container_number, 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
                DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
        END;
    END LOOP;

    -- If no containers were processed
    IF v_processed = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No overdue containers found.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Procedure completed successfully. Processed ' || v_processed || ' containers.');
    END IF;
END Send_Overdue_Notifications;
/



------Check Overdue Containers Processed
SELECT container_number, gate_out_date, gate_in_date, customs_status
FROM Container
WHERE gate_in_date > (gate_out_date + (SELECT free_time FROM ServiceContract WHERE service_contract_id = Container.service_contract_id))
  AND customs_status = 'No';

----Check Error Log Entries

SELECT * FROM ErrorLog WHERE affected_table = 'Container' ORDER BY error_timestamp DESC;


## Test Cases for `Send_Overdue_Notifications` Procedure

| Test Case ID | Container Number | Gate Out Date | Gate In Date | Free Time | Customs Status | Expected Outcome |
|-------------|--------------------|--------------|--------------|-----------|----------------|------------------|
| **TC1**     | `CONT123`          | `01-MAR-2025`| `15-MAR-2025`| `10`      | `No`           | Notification Sent (Overdue by 4 days) |
| **TC2**     | `CONT124`          | `01-MAR-2025` | `12-MAR-2025`| `10`     | `No`           | No Notification (Within free time) |
| **TC3**     | `CONT125`          | `01-MAR-2025` | `20-MAR-2025` | `10`    | `No`            | Notification Sent (Overdue by 9 days) |
| **TC4**     | `CONT126`          | `01-MAR-2025` | `15-MAR-2025` | `10`    | `Yes`          | No Notification (Customs cleared) |
| **TC5**     | `CONT127`          | `01-MAR-2025` | `05-MAR-2025` | `10`    | `No`           | No Notification (Gate in before free time ends) |
| **TC6**     | `INVALID`          | `01-MAR-2025` | `15-MAR-2025` | `10`    | `No`           | Error Logged - Container not found |
| **TC7**     | `CONT128`          | `01-MAR-2025` | `15-MAR-2025` | `10`    | `No`           | Error Logged - Customer email not found |
| **TC8**     | `CONT129`          | `01-MAR-2025` | `15-MAR-2025` | `10`    | `No`           | Email sending failed, error logged |
