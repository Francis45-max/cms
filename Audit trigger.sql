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



-----Trigger test cases

1. Insert Test Case
Scenario: Insert a new container record and check if an audit entry is made.

-- Insert a new container
INSERT INTO Container (container_number) VALUES ('C12345');

-- Check audit log
SELECT * FROM ContainerAuditLog WHERE affected_record_id = 'C12345';
Expected Result:

audit_action = 'INSERT'
old_value = NULL
new_value = 'C12345'


2. Update Test Case
Scenario: Update an existing container record and verify the audit log.

-- Update container number
UPDATE Container SET container_number = 'C67890' WHERE container_number = 'C12345';

-- Check audit log
SELECT * FROM ContainerAuditLog WHERE affected_record_id = 'C12345';
Expected Result:

audit_action = 'UPDATE'
old_value = 'C12345'
new_value = 'C67890'

3. Delete Test Case
Scenario: Delete an existing container record and ensure logging.

-- Delete the container
DELETE FROM Container WHERE container_number = 'C67890';

-- Check audit log
SELECT * FROM ContainerAuditLog WHERE affected_record_id = 'C67890';
Expected Result:

audit_action = 'DELETE'
old_value = 'C67890'
new_value = NULL
END;
/
