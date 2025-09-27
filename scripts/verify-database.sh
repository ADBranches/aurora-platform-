#!/bin/bash

set -e

echo "🔍 Verifying Aurora database setup..."

echo "1. Testing database connection..."
kubectl run postgres-test --rm -i --restart=Never --namespace aurora-dev \
  --image=postgres:15 \
  --env="PGPASSWORD=aurora123" -- \
  psql -h postgresql -U postgres -d aurora_events -c "SELECT '✅ Database connection successful' as status;"

echo "2. Listing all tables..."
kubectl run postgres-list-tables --rm -i --restart=Never --namespace aurora-dev \
  --image=postgres:15 \
  --env="PGPASSWORD=aurora123" -- \
  psql -h postgresql -U postgres -d aurora_events -c "\dt"

echo "3. Checking table structures..."
kubectl run postgres-check-structure --rm -i --restart=Never --namespace aurora-dev \
  --image=postgres:15 \
  --env="PGPASSWORD=aurora123" -- \
  psql -h postgresql -U postgres -d aurora_events -c "
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
"

echo "✅ Database verification complete!"
