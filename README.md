# Log Analytics Google Cloud

This repository documents my implementation of the "Log Analytics on Google Cloud" lab, where I explored Cloud Logging features to gain insights from applications running on Google Kubernetes Engine (GKE).

## Overview

Cloud Logging is a fully managed service that allows you to store, search, analyze, monitor, and alert on logging data and events from Google Cloud. In this project, I:

1. Set up and connected to a GKE cluster
2. Deployed the [Online Boutique microservices demo app](https://github.com/GoogleCloudPlatform/microservices-demo)
3. Configured log buckets with Log Analytics enabled
4. Created log sinks to route specific logs to storage
5. Ran analytical queries to extract insights from the application logs

## Architecture

The Online Boutique demo app contains multiple microservices:

![Online Boutique Architecture](images/architecture.png)


## Video

https://youtu.be/jit_lWJuHlM

## Setup Instructions

### Prerequisites
- Google Cloud account with billing enabled
- `gcloud` CLI installed and configured
- `kubectl` installed and configured

### 1. Infrastructure Setup

```bash
# Set the compute zone
gcloud config set compute/zone europe-west1-b

# Verify the cluster status
gcloud container clusters list

# Get the cluster credentials
gcloud container clusters get-credentials day2-ops --region europe-west1

# Verify the nodes are created and ready
kubectl get nodes
```

### 2. Deploy the Application

```bash
# Clone the repository
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git

# Navigate to the directory
cd microservices-demo

# Deploy the application to the cluster
kubectl apply -f release/kubernetes-manifests.yaml

# Verify all pods are running
kubectl get pods

# Get the external IP of the application
export EXTERNAL_IP=$(kubectl get service frontend-external -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo $EXTERNAL_IP

# Verify the application is accessible
curl -o /dev/null -s -w "%{http_code}\n" http://${EXTERNAL_IP}
```

### 3. Configure Log Analytics

#### Option 1: Upgrade an existing bucket
1. Navigate to Logging > Logs Storage
2. Click UPGRADE on an existing bucket (e.g., Default bucket)
3. Confirm the upgrade

#### Option 2: Create a new Log bucket
1. Navigate to Logging > Logs Storage
2. Click CREATE LOG BUCKET
3. Enter a name (e.g., day2ops-log)
4. Check "Upgrade to use Log Analytics" and "Create a new BigQuery dataset"
5. Enter a dataset name (e.g., day2ops_log)
6. Click Create bucket

### 4. Create a Log Sink

```bash
# Using the Google Cloud Console:
# 1. Navigate to Logging > Logs Explorer
# 2. Run the query: resource.type="k8s_container"
# 3. Click Actions > Create sink
# 4. Enter a name (e.g., day2ops-sink)
# 5. Select "Logging bucket" as the sink service
# 6. Select your new log bucket
# 7. Click Create sink
```

## Log Analysis Examples

Here are some example queries I ran to analyze logs from the application:

### Finding the most recent errors

```sql
SELECT
 TIMESTAMP,
 JSON_VALUE(resource.labels.container_name) AS container,
 json_payload
FROM
 `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
 severity="ERROR"
 AND json_payload IS NOT NULL
ORDER BY
 1 DESC
LIMIT
 50
```

### Finding min, max, and average latency

```sql
SELECT
hour,
MIN(took_ms) AS min,
MAX(took_ms) AS max,
AVG(took_ms) AS avg
FROM (
SELECT
  FORMAT_TIMESTAMP("%H", timestamp) AS hour,
  CAST( JSON_VALUE(json_payload,
      '$."http.resp.took_ms"') AS INT64 ) AS took_ms
FROM
  `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
  timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND json_payload IS NOT NULL
  AND SEARCH(labels,
    "frontend")
  AND JSON_VALUE(json_payload.message) = "request complete"
ORDER BY
  took_ms DESC,
  timestamp ASC )
GROUP BY
1
ORDER BY
1
```

### Counting Product page visits

```sql
SELECT
count(*)
FROM
`PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
text_payload like "GET %/product/L9ECAV7KIM %"
AND
timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
```

### Finding sessions that end with checkout

```sql
SELECT
 JSON_VALUE(json_payload.session),
 COUNT(*)
FROM
 `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
 JSON_VALUE(json_payload['http.req.method']) = "POST"
 AND JSON_VALUE(json_payload['http.req.path']) = "/cart/checkout"
 AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
GROUP BY
 JSON_VALUE(json_payload.session)
```

## Key Learnings

- Cloud Logging provides powerful insights into Kubernetes applications
- Log Analytics enables SQL-based querying against log data
- Combining BigQuery with Log buckets offers advanced analytical capabilities
- Proper log filtering helps manage costs and focus on relevant data

## References

- [Online Boutique Demo on GitHub](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
