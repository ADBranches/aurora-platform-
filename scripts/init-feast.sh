#!/bin/bash

# Initialize Feast Feature Store for Aurora

set -e

echo "📊 Initializing Feast feature store..."

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Wait for Feast
until docker-compose exec -T feast feast --version >/dev/null 2>&1; do
  echo "Waiting for Feast..."
  sleep 2
done

# Initialize Feast repository
docker-compose exec -T feast bash -c "cd /feast && feast init aurora_features || true"

# Create feature definition
cat << EOF > feast/aurora_features/feature_definitions.py
from datetime import timedelta
from feast import Entity, FeatureView, Field
from feast.types import Float32, String
from feast.infra.offline_stores.postgres import PostgreSQLOfflineStoreConfig
from feast.infra.online_stores.redis import RedisOnlineStoreConfig

project = "aurora_features"
registry = "/feast/aurora_features/registry.db"
provider = "local"
offline_store = PostgreSQLOfflineStoreConfig(
    host="postgres",
    port=5432,
    database="${POSTGRES_DB}",
    user="${POSTGRES_USER}",
    password="${POSTGRES_PASSWORD}"
)
online_store = RedisOnlineStoreConfig(
    connection_string="redis:6379,password=${REDIS_PASSWORD}"
)

# Define entity for inventory items
inventory_item = Entity(
    name="inventory_item",
    join_keys=["entity_id"],
    description="Inventory item entity for stock predictions"
)

# Define feature view for stock-out predictions
stock_features = FeatureView(
    name="stock_features",
    entities=[inventory_item],
    ttl=timedelta(days=30),
    schema=[
        Field(name="current_stock", dtype=Float32),
        Field(name="demand_forecast", dtype=Float32),
        Field(name="supply_delay_risk", dtype=Float32),
        Field(name="weather_impact", dtype=String)
    ],
    source="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}/ml_features"
)
EOF

# Apply Feast configuration
docker-compose exec -T feast bash -c "cd /feast/aurora_features && feast apply"

echo "✅ Feast feature store initialized!"
