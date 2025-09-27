import mlflow
from mlflow.tracking import MlflowClient

def register_best_model():
    """Register the best model from MLflow experiments"""
    client = MlflowClient()
    
    # Find the best run (highest test R² score)
    experiment = client.get_experiment_by_name("inventory-forecasting")
    runs = client.search_runs(
        experiment_ids=[experiment.experiment_id],
        order_by=["metrics.test_r2 DESC"]
    )
    
    if runs:
        best_run = runs[0]
        model_uri = f"runs:/{best_run.info.run_id}/inventory-forecast-model"
        
        # Register model
        registered_model = mlflow.register_model(
            model_uri=model_uri,
            name="inventory-demand-forecaster"
        )
        
        print(f"Registered model: {registered_model.name} version {registered_model.version}")
        
        # Transition to Production
        client.transition_model_version_stage(
            name="inventory-demand-forecaster",
            version=registered_model.version,
            stage="Production"
        )
        
        return registered_model
    else:
        print("No runs found!")
        return None

if __name__ == "__main__":
    register_best_model()
