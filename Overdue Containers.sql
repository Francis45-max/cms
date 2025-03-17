CREATE OR REPLACE PROCEDURE Send_Overdue_Notifications IS
    CURSOR overdue_containers IS
        SELECT c.container_number, c.customer_id, cu.customer_name, cu.region,
               c.gate_out_date, c.gate_in_date, c.customs_status,
               (c.gate_in_date - (c.gate_out_date + sc.free_time)) AS overdue_days
        FROM Container c
        JOIN Customer cu ON c.customer_id = cu.cust_id
        JOIN ServiceContract sc ON c.service_contract_id = sc.service_contract_id
        WHERE c.gate_in_date > (c.gate_out_date + sc.free_time)
          AND c.customs_status = 'No'; -- Containers with customs clearance delays

    v_message VARCHAR2(1000);
    v_email VARCHAR2(100);
    v_phone VARCHAR2(20);
    v_error_message VARCHAR2(1000);
    v_container_count NUMBER := 0; -- Counter to check if any containers are found
BEGIN
    -- Check if any containers are overdue
    SELECT COUNT(*)
    NUMBERO v_container_count
    FROM Container c
    JOIN Customer cu ON c.customer_id = cu.cust_id
    JOIN ServiceContract sc ON c.service_contract_id = sc.service_contract_id
    WHERE c.gate_in_date > (c.gate_out_date + sc.free_time)
      AND c.customs_status = 'No';

    -- If no containers are found, raise an application error and stop execution
    IF v_container_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'No overdue containers found. Procedure execution stopped.');
    END IF;

    -- Process overdue containers
    FOR container IN overdue_containers LOOP
        BEGIN
            -- Construct the notification message
            v_message := 'Dear ' || container.customer_name || ',' || CHR(10) ||
                          'Your container ' || container.container_number || ' is overdue by ' ||
                          container.overdue_days || ' days.' || CHR(10) ||
                          'Please take necessary action to avoid additional charges.' || CHR(10) ||
                          'Thank you,' || CHR(10) ||
                          'Logistics Management Team';

            -- Fetch customer email and phone
            BEGIN
                SELECT email, phone NUMBERO v_email, v_phone
                FROM Customer
                WHERE cust_id = container.customer_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_error_message := 'Customer details not found for container ' || container.container_number;
                    -- Log the error and continue processing the next container
                    INSERT NUMBERO ErrorLog (error_id, error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id)
                    VALUES (error_log_seq.NEXTVAL, SYSTIMESTAMP, v_error_message, 'Customer', container.customer_id, 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
                    DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
                    CONTINUE; -- Skip to the next container
            END;

            -- Send email (assuming UTL_MAIL is configured)
            BEGIN
                UTL_MAIL.SEND(
                    sender => 'noreply@logistics.com',
                    recipients => v_email,
                    subject => 'Overdue Container Notification',
                    message => v_message
                );
                DBMS_OUTPUT.PUT_LINE('Email sent to ' || v_email || ' for container ' || container.container_number);
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := 'Failed to send email to ' || v_email || ': ' || SQLERRM;
                    -- Log the error and continue processing the next container
                    INSERT NUMBERO ErrorLog (error_id, error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id)
                    VALUES (error_log_seq.NEXTVAL, SYSTIMESTAMP, v_error_message, 'Container', container.container_number, 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
                    DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
                    CONTINUE; -- Skip to the next container
            END;

            -- Send SMS (assuming an SMS gateway API is NUMBERegrated)
            BEGIN
                -- Replace with your SMS API endpoNUMBER and parameters
                UTL_HTTP.REQUEST(
                    url => 'https://sms-api.example.com/send',
                    method => 'POST',
                    body => 'phone=' || v_phone || '&message=' || v_message
                );
                DBMS_OUTPUT.PUT_LINE('SMS sent to ' || v_phone || ' for container ' || container.container_number);
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_message := 'Failed to send SMS to ' || v_phone || ': ' || SQLERRM;
                    -- Log the error and continue processing the next container
                    INSERT NUMBERO ErrorLog (error_id, error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id)
                    VALUES (error_log_seq.NEXTVAL, SYSTIMESTAMP, v_error_message, 'Container', container.container_number, 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
                    DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
                    CONTINUE; -- Skip to the next container
            END;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log any unexpected errors and continue processing the next container
                v_error_message := 'Unexpected error for container ' || container.container_number || ': ' || SQLERRM;
                INSERT NUMBERO ErrorLog (error_id, error_timestamp, error_message, affected_table, affected_record_id, resolved_status, user_name, session_id)
                VALUES (error_log_seq.NEXTVAL, SYSTIMESTAMP, v_error_message, 'Container', container.container_number, 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
                DBMS_OUTPUT.PUT_LINE('Error: ' || v_error_message);
                CONTINUE; -- Skip to the next container
        END;
    END LOOP;
END Send_Overdue_Notifications;
/