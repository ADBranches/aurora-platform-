from feast import Entity, FeatureView, Field, FileSource
from feast.types import Float32, Int64, String
from datetime import timedelta
from entities import product, customer, supplier

# Define feature views with proper schemas
product_demand_features = FeatureView(
    name="product_demand_features",
    entities=[product],
    ttl=timedelta(days=30),
    schema=[
        Field(name="avg_demand_7d", dtype=Float32),
        Field(name="avg_demand_30d", dtype=Float32),
        Field(name="demand_volatility", dtype=Float32),
        Field(name="seasonality_factor", dtype=Float32),
    ],
    online=True,
    tags={"team": "demand-forecasting"},
)

customer_behavior_features = FeatureView(
    name="customer_behavior_features", 
    entities=[customer],
    ttl=timedelta(days=90),
    schema=[
        Field(name="total_spend_30d", dtype=Float32),
        Field(name="order_frequency", dtype=Float32),
        Field(name="avg_order_value", dtype=Float32),
        Field(name="preferred_category", dtype=String),
    ],
    online=True,
    tags={"team": "customer-analytics"},
)

supplier_performance_features = FeatureView(
    name="supplier_performance_features",
    entities=[supplier],
    ttl=timedelta(days=60),
    schema=[
        Field(name="on_time_delivery_rate", dtype=Float32),
        Field(name="quality_rating", dtype=Float32),
        Field(name="avg_lead_time", dtype=Float32),
        Field(name="price_competitiveness", dtype=Float32),
    ],
    online=True,
    tags={"team": "procurement"},
)
