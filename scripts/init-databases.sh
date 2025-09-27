#!/bin/bash

# Database Initialization Script

set -e

echo "🗃️ Initializing Aurora databases..."

# Create core tables in PostgreSQL
kubectl run postgres-init --rm -i --restart='Never' --namespace aurora-dev \
  --image docker.io/bitnami/postgresql:15.0.0 \
  --env="PGPASSWORD=aurora123" \
  --command -- psql -h postgresql -U postgres -d aurora_events -c "
-- Events table for ERP events
CREATE TABLE IF NOT EXISTS erp_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_erp_events_type ON erp_events(event_type);
CREATE INDEX IF NOT EXISTS idx_erp_events_entity ON erp_events(entity_id);
CREATE INDEX IF NOT EXISTS idx_erp_events_created ON erp_events(created_at);

-- ML features table
CREATE TABLE IF NOT EXISTS ml_features (
    feature_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    feature_name VARCHAR(100) NOT NULL,
    feature_value JSONB NOT NULL,
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_to TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ml_features_entity ON ml_features(entity_type, entity_id);
"

echo "✅ Database initialization complete!"
