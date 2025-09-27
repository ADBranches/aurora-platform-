from feast import FileSource
from feast.data_format import ParquetFormat

# Historical data sources
product_stats_source = FileSource(
    name="product_stats",
    path="s3://aurora-data/historical/product_stats.parquet",
    file_format=ParquetFormat(),
    timestamp_field="event_timestamp"
)

sales_history_source = FileSource(
    name="sales_history", 
    path="s3://aurora-data/historical/sales.parquet",
    file_format=ParquetFormat(),
    timestamp_field="event_timestamp"
)
