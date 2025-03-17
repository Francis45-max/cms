---Procedure to Extend Free Time Based On Appointment

CREATE OR REPLACE PROCEDURE Extend_Free_Time_Based_On_Appointment 
IS
    TYPE t_cont IS TABLE OF ServiceContract%ROWTYPE; 
    TYPE t_audit_log IS TABLE OF ContainerAuditLog%ROWTYPE; 

    CURSOR cur_cont IS 
        SELECT cont.service_contract_id, cont.free_time, cont.new_lfd, t.appointment_status
        FROM ServiceContract cont
        JOIN Container c ON cont.service_contract_id = c.service_contract_id
        JOIN Terminal t ON c.location_id = t.location_id
        WHERE t.appointment_status LIKE 'unavailable for % days';

    v_cont   t_cont;
    v_audit_logs  t_audit_log;
    v_days_to_extend NUMBER;
    
BEGIN
    -- Open cursor and fetch records in bulk
    OPEN cur_cont;
    LOOP
        FETCH cur_cont BULK COLLECT INTO v_cont LIMIT 100; -- Process in batches
        
        EXIT WHEN v_cont.COUNT = 0;
        
        FOR i IN 1 .. v_cont.COUNT LOOP
            -- Extract number of unavailable days
            v_days_to_extend := TO_NUMBER(REGEXP_SUBSTR(v_cont(i).appointment_status, '\d+'));

            -- Update New LFD based on the condition
            UPDATE ServiceContract 
            SET new_lfd = 
                CASE 
                    WHEN v_days_to_extend IS NOT NULL THEN free_time + v_days_to_extend
                    ELSE free_time -- If container is not affected, keep it same
                END
            WHERE service_contract_id = v_cont(i).service_contract_id;

            -- Store audit log entry
            v_audit_logs.EXTEND;
            v_audit_logs(v_audit_logs.LAST).audit_timestamp := SYSTIMESTAMP;
            v_audit_logs(v_audit_logs.LAST).audit_action := 'UPDATE';
            v_audit_logs(v_audit_logs.LAST).affected_table := 'ServiceContract';
            v_audit_logs(v_audit_logs.LAST).affected_record_id := v_cont(i).service_contract_id;
            v_audit_logs(v_audit_logs.LAST).old_value := TO_CLOB(v_cont(i).new_lfd);
            v_audit_logs(v_audit_logs.LAST).new_value := TO_CLOB(
                CASE 
                    WHEN v_days_to_extend IS NOT NULL THEN v_cont(i).free_time + v_days_to_extend
                    ELSE v_cont(i).free_time
                END
            );
            v_audit_logs(v_audit_logs.LAST).user_name := USER;
            v_audit_logs(v_audit_logs.LAST).session_id := SYS_CONTEXT('USERENV', 'SESSIONID');
        END LOOP;

        -- Insert all audit logs in bulk
        FORALL i IN 1 .. v_audit_logs.COUNT
            INSERT INTO ContainerAuditLog VALUES v_audit_logs(i);

        COMMIT; -- Commit after batch processing

    END LOOP;
    CLOSE cur_cont;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO ErrorLog (error_timestamp, error_message, affected_table, resolved_status, user_name, session_id)
        VALUES (SYSTIMESTAMP, SQLERRM, 'ServiceContract', 'No', USER, SYS_CONTEXT('USERENV', 'SESSIONID'));
        COMMIT;
END Extend_Free_Time_Based_On_Appointment;
/
