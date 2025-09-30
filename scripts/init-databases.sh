#!/bin/bash

# Aurora Database Initialization Script (Docker Compose)

set -e

echo "🗃️ Initializing Aurora databases (PostgreSQL, MongoDB)..."

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Default values
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-aurora123}
POSTGRES_DB=${POSTGRES_DB:-aurora_events}
MONGO_USER=${MONGO_USER:-aurora_mongo}
MONGO_PASSWORD=${MONGO_PASSWORD:-aurora-mongo-123}
MONGO_DB=${MONGO_DB:-aurora_data}

echo "📊 Using database configurations:"
echo "   PostgreSQL: ${POSTGRES_USER}@${POSTGRES_DB}"
echo "   MongoDB: ${MONGO_USER}@${MONGO_DB}"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL..."
until docker compose exec -T postgres pg_isready -U $POSTGRES_USER >/dev/null 2>&1; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Create PostgreSQL users and schema
echo "👥 Creating PostgreSQL users and schema..."
docker compose exec -T postgres psql -U $POSTGRES_USER -d $POSTGRES_DB << 'EOF'
-- Create users
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'aurora_reader') THEN
        CREATE USER aurora_reader WITH PASSWORD 'reader123';
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'aurora_writer') THEN
        CREATE USER aurora_writer WITH PASSWORD 'writer123';
    END IF;
END
$$;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Core events table with partitioning by month
CREATE TABLE IF NOT EXISTS erp_events (
    event_id UUID DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    PRIMARY KEY (event_id, created_at)
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE IF NOT EXISTS erp_events_2024_01 PARTITION OF erp_events 
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE IF NOT EXISTS erp_events_2024_02 PARTITION OF erp_events 
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE IF NOT EXISTS erp_events_2025_01 PARTITION OF erp_events 
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE IF NOT EXISTS erp_events_2025_02 PARTITION OF erp_events 
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- ML features table
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_erp_events_type_entity ON erp_events(event_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_erp_events_created_processed ON erp_events(created_at, processed);
CREATE INDEX IF NOT EXISTS idx_ml_features_lookup ON ml_features(entity_type, entity_id, valid_from, valid_to);
CREATE INDEX IF NOT EXISTS idx_gateway_audit_created ON gateway_audit(created_at);
CREATE INDEX IF NOT EXISTS idx_gateway_audit_path ON gateway_audit(path, created_at);

-- Grant permissions
GRANT CONNECT ON DATABASE aurora_events TO aurora_reader, aurora_writer;
GRANT USAGE ON SCHEMA public TO aurora_reader, aurora_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO aurora_reader;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO aurora_writer;

-- Insert initial data
INSERT INTO gateway_audit (request_id, method, path, status_code, api_key_hash) 
VALUES 
    ('init-001', 'POST', '/api/v1/apikeys', 201, crypt('web-app-key-123', gen_salt('bf'))),
    ('init-002', 'POST', '/api/v1/apikeys', 201, crypt('mobile-app-key-456', gen_salt('bf')))
ON CONFLICT DO NOTHING;
EOF

echo "✅ PostgreSQL schema created successfully!"

# Wait for MongoDB to be ready (if MongoDB service exists)
if docker compose ps mongodb --status running | grep -q "mongodb"; then
    echo "⏳ Waiting for MongoDB..."
    until docker compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; do
        echo "Waiting for MongoDB..."
        sleep 2
    done

    echo "✅ MongoDB is ready!"
    
    # Initialize MongoDB collections
    echo "📝 Creating MongoDB collections..."
    docker compose exec -T mongodb mongosh << EOF
use $MONGO_DB

// Create external_data collection with schema validation
db.createCollection('external_data', {
  validator: {
    \$jsonSchema: {
      bsonType: 'object',
      required: ['source', 'data', 'timestamp'],
      properties: {
        source: { bsonType: 'string' },
        data: { bsonType: 'object' },
        timestamp: { bsonType: 'date' },
        metadata: { bsonType: 'object' },
        status: { bsonType: 'string', enum: ['active', 'archived'] }
      }
    }
  }
});

// Create audit_logs collection
db.createCollection('audit_logs', {
  validator: {
    \$jsonSchema: {
      bsonType: 'object',
      required: ['request_id', 'action', 'timestamp'],
      properties: {
        request_id: { bsonType: 'string' },
        action: { bsonType: 'string' },
        user_id: { bsonType: 'string' },
        resource: { bsonType: 'string' },
        timestamp: { bsonType: 'date' },
        details: { bsonType: 'object' }
      }
    }
  }
});

// Create indexes
db.external_data.createIndex({ source: 1, timestamp: -1 });
db.external_data.createIndex({ status: 1 });
db.audit_logs.createIndex({ request_id: 1, timestamp: -1 });
db.audit_logs.createIndex({ user_id: 1, timestamp: -1 });
db.audit_logs.createIndex({ action: 1, resource: 1 });

// Insert sample data
db.external_data.insertOne({
  source: 'erp_system',
  data: {
    customer_id: 'cust_001',
    order_total: 1500.00,
    items: 5
  },
  timestamp: new Date(),
  metadata: {
    version: '1.0',
    processed: false
  },
  status: 'active'
});

print('✅ MongoDB collections created and initialized');
EOF

else
    echo "⚠️  MongoDB not running, skipping MongoDB initialization"
fi

# # Wait for Kafka to be ready
# echo "⏳ Waiting for Kafka..."
# until docker compose exec -T kafka kafka-topics.sh --list --bootstrap-server kafka:9092 >/dev/null 2>&1; do
#   echo "Waiting for Kafka..."
#   sleep 2
# done

# # Initialize Kafka topics
# echo "📤 Initializing Kafka topics..."
# docker compose exec -T kafka kafka-topics.sh --create --topic erp-events --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists || true
# docker compose exec -T kafka kafka-topics.sh --create --topic ml-features --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists || true
# docker compose exec -T kafka kafka-topics.sh --create --topic predictions --bootstrap-server kafka:9092 --partitions 3 --replication-factor 1 --if-not-exists || true

# echo "✅ Kafka topics created successfully!"
# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka..."
until nc -z localhost 9092; do
  echo "Waiting for Kafka..."
  sleep 2
done

# Additional wait for Kafka to fully initialize
echo "Kafka port open, waiting for service to stabilize..."
sleep 10

# Initialize Kafka topics
echo "📤 Initializing Kafka topics..."
docker compose exec -T kafka kafka-topics.sh --create --topic erp-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists || true
docker compose exec -T kafka kafka-topics.sh --create --topic ml-features --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists || true
docker compose exec -T kafka kafka-topics.sh --create --topic predictions --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists || true

echo "✅ Kafka topics created successfully!"

# Wait for Feast to be ready (optional)
echo "⏳ Waiting for Feast..."
if docker compose ps feast | grep -q "Up"; then
  # Use port connectivity check instead of HTTP endpoint
  until nc -z localhost 6566; do
    echo "Waiting for Feast..."
    sleep 2
  done
  
  # Initialize Feast feature store
  echo "📊 Initializing Feast feature store..."
  docker compose exec -T feast bash -c "cd /feast && feast init aurora_features || true"
  docker compose exec -T feast bash -c "cd /feast/aurora_features && feast apply"
else
  echo "⚠️  Feast not running, skipping Feast initialization"
fi

echo "🎉 All databases and infrastructure initialized successfully!"
echo ""
echo "📋 Summary:"
echo "   ✅ PostgreSQL: Users, schema, and initial data created"
echo "   ✅ MongoDB: Collections and indexes created (if running)"
echo "   ✅ Kafka: Topics created"
echo "   ✅ Feast: Feature store initialized (if running)"
