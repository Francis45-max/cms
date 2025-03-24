CREATE TABLE Region (
    region_id NUMBER PRIMARY KEY,
    region_name VARCHAR2(100) NOT NULL
);

CREATE TABLE Customer (
    cust_id VARCHAR2(40) PRIMARY KEY,
    customer_name VARCHAR2(255) NOT NULL,
    region_id NUMBER,
    postal_code VARCHAR2(255),
    active_status VARCHAR2(10) NOT NULL,
    email VARCHAR2(255),
    phone VARCHAR2(20),
    FOREIGN KEY (region_id) REFERENCES Region(region_id)
);

CREATE TABLE Location (
    location_id NUMBER PRIMARY KEY,
    location_name VARCHAR2(255) NOT NULL
);

CREATE TABLE Terminal (
    terminal_id NUMBER PRIMARY KEY,
    location_id NUMBER NOT NULL,
    port_closure_dates DATE,
    terminal_name VARCHAR2(255) NOT NULL,
    appointment_status VARCHAR2(100),
    gate_out_date DATE,
    gate_in_date DATE,
    FOREIGN KEY (location_id) REFERENCES Location(location_id)
);

CREATE TABLE Currency (
    currency_id NUMBER PRIMARY KEY,
    region_id NUMBER NOT NULL,
    activity_currency VARCHAR2(50) NOT NULL,
    billed_currency VARCHAR2(50) NOT NULL,
    conversion_rate DECIMAL(10, 2) NOT NULL,
    charges DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (region_id) REFERENCES Region(region_id)
);

CREATE TABLE ServiceContract (
    service_contract_id VARCHAR2(40) PRIMARY KEY,
    cust_id VARCHAR2(40) NOT NULL,
    location_id NUMBER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    free_time NUMBER NOT NULL,
    new_lfd NUMBER DEFAULT NULL, -- Allow updates later
    status VARCHAR2(20) CHECK (status IN ('Active', 'Expired')),
    FOREIGN KEY (cust_id) REFERENCES Customer(cust_id),
    FOREIGN KEY (location_id) REFERENCES Location(location_id)
);

CREATE TABLE Container (
    container_number VARCHAR2(50) PRIMARY KEY,
    customer_id VARCHAR2(40),
    location_id NUMBER,
    service_contract_id VARCHAR2(40),
    customs_status VARCHAR2(3) CHECK (customs_status IN ('Yes', 'No')),
    appointment_status VARCHAR2(100), -- Matches Terminal.appointment_status
    gate_out_date DATE,
    gate_in_date DATE,
    FOREIGN KEY (customer_id) REFERENCES Customer(cust_id),
    FOREIGN KEY (service_contract_id) REFERENCES ServiceContract(service_contract_id),
    FOREIGN KEY (location_id) REFERENCES Location(location_id)
);

CREATE TABLE Document (
    customer_license_no VARCHAR2(50) PRIMARY KEY,
    aes VARCHAR2(255),
    si VARCHAR2(255),
    cust_id VARCHAR2(40),
    FOREIGN KEY (cust_id) REFERENCES Customer(cust_id)
);

CREATE TABLE ErrorLog (
    error_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    error_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    error_message CLOB NOT NULL,
    affected_table VARCHAR2(100) NOT NULL,
    affected_record_id VARCHAR2(100) NOT NULL,
    resolved_status VARCHAR2(3) CHECK (resolved_status IN ('Yes', 'No')) DEFAULT 'No',
    user_name VARCHAR2(100),
    session_id VARCHAR2(100)
);

CREATE TABLE ContainerAuditLog (
    audit_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    audit_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    audit_action VARCHAR2(10) CHECK (audit_action IN ('INSERT', 'UPDATE', 'DELETE')) NOT NULL,
    affected_table VARCHAR2(50) DEFAULT 'ServiceContract' NOT NULL, -- Reflects actual updates
    affected_record_id VARCHAR2(100) NOT NULL,
    old_value VARCHAR2(4000),  -- Stores old details (before update)
    new_value VARCHAR2(4000),  -- Stores new details (after update)
    user_name VARCHAR2(100),
    session_id VARCHAR2(100)
);
