import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import mlflow
import mlflow.sklearn
import joblib
from datetime import datetime

def generate_training_data():
    """Generate simulated inventory training data"""
    np.random.seed(42)
    
    dates = pd.date_range(start='2023-01-01', end='2024-01-15', freq='D')
    products = [f'PROD-{i:03d}' for i in range(1, 51)]  # 50 products
    
    data = []
    for date in dates:
        for product in products:
            # Simulate sales patterns (seasonality + trend + noise)
            base_demand = 10 + 5 * np.sin(2 * np.pi * date.dayofyear / 365)
            trend = 0.01 * (date - dates[0]).days
            noise = np.random.normal(0, 2)
            
            demand = max(0, int(base_demand + trend + noise))
            
            data.append({
                'date': date,
                'product_id': product,
                'day_of_week': date.dayofweek,
                'day_of_year': date.dayofyear,
                'month': date.month,
                'historical_demand_7d': demand + np.random.normal(0, 1),
                'historical_demand_30d': demand * 4 + np.random.normal(0, 2),
                'price': np.random.uniform(10, 100),
                'is_weekend': 1 if date.dayofweek >= 5 else 0,
                'demand': demand
            })
    
    return pd.DataFrame(data)

def train_model():
    """Train the inventory demand forecasting model"""
    # Start MLflow experiment
    mlflow.set_experiment("inventory-forecasting")
    
    with mlflow.start_run():
        # Generate training data
        print("Generating training data...")
        df = generate_training_data()
        
        # Prepare features and target
        feature_columns = ['day_of_week', 'day_of_year', 'month', 
                          'historical_demand_7d', 'historical_demand_30d',
                          'price', 'is_weekend']
        
        X = df[feature_columns]
        y = df['demand']
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Train model
        print("Training Random Forest model...")
        model = RandomForestRegressor(
            n_estimators=100,
            max_depth=10,
            random_state=42
        )
        
        model.fit(X_train, y_train)
        
        # Evaluate model
        train_score = model.score(X_train, y_train)
        test_score = model.score(X_test, y_test)
        
        print(f"Training R² score: {train_score:.3f}")
        print(f"Test R² score: {test_score:.3f}")
        
        # Log parameters and metrics
        mlflow.log_param("n_estimators", 100)
        mlflow.log_param("max_depth", 10)
        mlflow.log_metric("train_r2", train_score)
        mlflow.log_metric("test_r2", test_score)
        
        # Log model
        mlflow.sklearn.log_model(model, "inventory-forecast-model")
        
        # Save model locally
        joblib.dump(model, 'models/inventory_model.joblib')
        
        print("Model training complete and logged to MLflow!")
        
        return model

if __name__ == "__main__":
    train_model()
