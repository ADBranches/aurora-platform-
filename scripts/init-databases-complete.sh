#!/bin/bash

# Complete Database Initialization Script

set -e

echo "🗃️ Initializing complete Aurora database schema..."

# Create comprehensive database structure
kubectl run postgres-init --rm -i --restart='Never' --namespace aurora-dev \
  --image docker.io/bitnami/postgresql:15.0.0 \
  --env="PGPASSWORD=aurora123" \
  --command -- psql -h postgresql -U postgres -d aurora_events -c "

-- Create extensions
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";

-- Core events table with partitioning by month
CREATE TABLE IF NOT EXISTS erp_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT
) PARTITION BY RANGE (created_at);

-- Create monthly partitions for current and next month
CREATE TABLE IF NOT EXISTS erp_events_2024_01 PARTITION OF erp_events 
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE IF NOT EXISTS erp_events_2024_02 PARTITION OF erp_events 
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- ML features table with versioning
CREATE TABLE IF NOT EXISTS ml_features (
    feature_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    feature_name VARCHAR(100) NOT NULL,
    feature_value JSONB NOT NULL,
    feature_version INTEGER DEFAULT 1,
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_to TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(entity_type, entity_id, feature_name, feature_version)
);

-- API gateway audit log
CREATE TABLE IF NOT EXISTS gateway_audit (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id VARCHAR(100) NOT NULL,
    client_ip INET,
    user_agent TEXT,
    method VARCHAR(10) NOT NULL,
    path VARCHAR(500) NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    api_key_hash TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create performance indexes
CREATE INDEX IF NOT EXISTS idx_erp_events_type_entity ON erp_events(event_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_erp_events_created_processed ON erp_events(created_at, processed);
CREATE INDEX IF NOT EXISTS idx_ml_features_lookup ON ml_features(entity_type, entity_id, valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_gateway_audit_created ON gateway_audit(created_at);
CREATE INDEX IF NOT EXISTS idx_gateway_audit_path ON gateway_audit(path, created_at);

-- Create read-only user for microservices
CREATE USER aurora_reader WITH PASSWORD 'reader123';
GRANT CONNECT ON DATABASE aurora_events TO aurora_reader;
GRANT USAGE ON SCHEMA public TO aurora_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO aurora_reader;

-- Create read-write user for services
CREATE USER aurora_writer WITH PASSWORD 'writer123';
GRANT CONNECT ON DATABASE aurora_events TO aurora_writer;
GRANT USAGE ON SCHEMA public TO aurora_writer;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO aurora_writer;

-- Insert initial API keys for Kong
INSERT INTO gateway_audit (request_id, method, path, status_code, api_key_hash) 
VALUES 
    ('init-001', 'POST', '/api/v1/apikeys', 201, crypt('web-app-key-123', gen_salt('bf'))),
    ('init-002', 'POST', '/api/v1/apikeys', 201, crypt('mobile-app-key-456', gen_salt('bf')))
ON CONFLICT DO NOTHING;

"

echo "✅ Complete database schema initialized!"
