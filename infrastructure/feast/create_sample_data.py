# infrastructure/feast/create_sample_data.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os

def create_sample_data():
    """Create realistic sample data for the ERP feature store"""
    
    # Create directories if they don't exist
    os.makedirs('data/raw/product_demand', exist_ok=True)
    os.makedirs('data/raw/customer_behavior', exist_ok=True)
    os.makedirs('data/raw/supplier_performance', exist_ok=True)
    
    print("📊 Creating sample ERP data...")
    
    # 1. Product Demand Data
    product_ids = [f"PROD_{i:05d}" for i in range(1, 101)]
    base_date = datetime.now() - timedelta(days=60)
    
    product_data = []
    for i, product_id in enumerate(product_ids):
        for day in range(60):
            event_date = base_date + timedelta(days=day)
            product_data.append({
                'product_id': product_id,
                'event_timestamp': event_date,
                'created_timestamp': event_date,
                'avg_demand_7d': np.random.uniform(5, 50),
                'avg_demand_30d': np.random.uniform(20, 200),
                'demand_volatility': np.random.uniform(0.1, 0.8),
                'seasonality_factor': np.random.uniform(0.7, 1.3)
            })
    
    product_df = pd.DataFrame(product_data)
    # Ensure timestamps are properly formatted
    product_df['event_timestamp'] = pd.to_datetime(product_df['event_timestamp'])
    product_df['created_timestamp'] = pd.to_datetime(product_df['created_timestamp'])
    product_df.to_parquet('data/raw/product_demand/product_demand_data.parquet')
    print(f"✅ Created product demand data: {len(product_df)} records")
    
    # 2. Customer Behavior Data
    customer_ids = [f"CUST_{i:06d}" for i in range(1, 501)]
    
    customer_data = []
    for i, customer_id in enumerate(customer_ids):
        event_date = base_date + timedelta(days=np.random.randint(0, 90))
        customer_data.append({
            'customer_id': customer_id,
            'event_timestamp': event_date,
            'created_timestamp': event_date,
            'total_spend_30d': np.random.uniform(100, 10000),
            'order_frequency': np.random.uniform(1, 20),
            'avg_order_value': np.random.uniform(25, 500),
            'preferred_category': np.random.choice(['ELECTRONICS', 'CLOTHING', 'HOME_GOODS', 'BOOKS', 'SPORTS'])
        })
    
    customer_df = pd.DataFrame(customer_data)
    customer_df['event_timestamp'] = pd.to_datetime(customer_df['event_timestamp'])
    customer_df['created_timestamp'] = pd.to_datetime(customer_df['created_timestamp'])
    customer_df.to_parquet('data/raw/customer_behavior/customer_behavior_data.parquet')
    print(f"✅ Created customer behavior data: {len(customer_df)} records")
    
    # 3. Supplier Performance Data
    supplier_ids = [f"SUPP_{i:04d}" for i in range(1, 51)]
    
    supplier_data = []
    for i, supplier_id in enumerate(supplier_ids):
        event_date = base_date + timedelta(days=np.random.randint(0, 60))
        supplier_data.append({
            'supplier_id': supplier_id,
            'event_timestamp': event_date,
            'created_timestamp': event_date,
            'on_time_delivery_rate': np.random.uniform(0.85, 0.99),
            'quality_rating': np.random.uniform(3.5, 5.0),
            'avg_lead_time': np.random.uniform(7, 30),
            'price_competitiveness': np.random.uniform(0.9, 1.1)
        })
    
    supplier_df = pd.DataFrame(supplier_data)
    supplier_df['event_timestamp'] = pd.to_datetime(supplier_df['event_timestamp'])
    supplier_df['created_timestamp'] = pd.to_datetime(supplier_df['created_timestamp'])
    supplier_df.to_parquet('data/raw/supplier_performance/supplier_performance_data.parquet')
    print(f"✅ Created supplier performance data: {len(supplier_df)} records")
    
    print("\n🎉 Sample data creation complete!")
    print("📁 Data locations:")
    print("   - Product demand: infrastructure/feast/data/raw/product_demand/")
    print("   - Customer behavior: infrastructure/feast/data/raw/customer_behavior/")
    print("   - Supplier performance: infrastructure/feast/data/raw/supplier_performance/")

if __name__ == "__main__":
    create_sample_data()
    