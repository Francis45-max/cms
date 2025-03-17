CREATE OR REPLACE TRIGGER container_audit
AFTER INSERT OR UPDATE OR DELETE ON Container
FOR EACH ROW
BEGIN
    INSERT INTO ContainerAuditLog (
        audit_timestamp, audit_action, affected_record_id, 
        old_value, new_value, user_name, session_id
    )
    VALUES (
        SYSTIMESTAMP, 
        CASE 
            WHEN INSERTING THEN 'INSERT'
            WHEN UPDATING THEN 'UPDATE'
            WHEN DELETING THEN 'DELETE'
        END,
        COALESCE(:NEW.container_number, :OLD.container_number),
        CASE WHEN UPDATING OR DELETING THEN :OLD.container_number ELSE NULL END,
        CASE WHEN INSERTING OR UPDATING THEN :NEW.container_number ELSE NULL END,
        USER, 
        SYS_CONTEXT('USERENV', 'SESSIONID')
    );
END;
/
