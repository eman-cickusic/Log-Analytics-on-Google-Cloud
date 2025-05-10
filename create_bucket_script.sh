#!/bin/bash
# create_log_bucket.sh - Script to create a Log Analytics enabled bucket and sink

# Exit on error
set -e

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)
echo "Working with project: $PROJECT_ID"

# Set variables
BUCKET_NAME="day2ops-log"
SINK_NAME="day2ops-sink"
BQ_DATASET="day2ops_log"
FILTER="resource.type=\"k8s_container\""

# Create log bucket with Log Analytics enabled
echo "Creating log bucket '$BUCKET_NAME' with Log Analytics enabled..."
gcloud logging buckets create $BUCKET_NAME \
  --location=global \
  --description="Log bucket for Day2Ops demo" \
  --enable-analytics

# Create BigQuery dataset
echo "Creating BigQuery dataset '$BQ_DATASET'..."
bq --location=US mk --dataset $PROJECT_ID:$BQ_DATASET

# Link bucket and dataset
echo "Linking log bucket to BigQuery dataset..."
gcloud logging links create \
  --bucket=$BUCKET_NAME \
  --dataset=$PROJECT_ID:$BQ_DATASET

# Create log sink
echo "Creating log sink '$SINK_NAME'..."
BUCKET_DESTINATION="logging.googleapis.com/projects/$PROJECT_ID/locations/global/buckets/$BUCKET_NAME"

gcloud logging sinks create $SINK_NAME \
  $BUCKET_DESTINATION \
  --log-filter="$FILTER" \
  --description="Sink for Day2Ops demo"

echo ""
echo "==== Log Analytics Setup Complete ===="
echo "Log bucket: $BUCKET_NAME"
echo "Log sink: $SINK_NAME"
echo "BigQuery dataset: $BQ_DATASET"
echo ""
echo "To view your logs in Log Analytics:"
echo "1. Go to the GCP Console > Logging > Log Analytics"
echo "2. Select your bucket view"
echo "3. Start running queries against your log data"
echo ""
