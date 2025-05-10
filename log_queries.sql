-- Example Log Analytics queries for GKE applications

-- Replace PROJECT_ID with your actual project ID

-- 1. Find the most recent errors from containers
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
  50;

-- 2. Find min, max, and average latency per hour for the frontend service
SELECT
  hour,
  MIN(took_ms) AS min,
  MAX(took_ms) AS max,
  AVG(took_ms) AS avg
FROM (
  SELECT
    FORMAT_TIMESTAMP("%H", timestamp) AS hour,
    CAST(JSON_VALUE(json_payload, '$."http.resp.took_ms"') AS INT64) AS took_ms
  FROM
    `PROJECT_ID.global.day2ops-log._AllLogs`
  WHERE
    timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    AND json_payload IS NOT NULL
    AND SEARCH(labels, "frontend")
    AND JSON_VALUE(json_payload.message) = "request complete"
  ORDER BY
    took_ms DESC,
    timestamp ASC
)
GROUP BY
  1
ORDER BY
  1;

-- 3. Count visits to a specific product page in the past hour
SELECT
  count(*)
FROM
  `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
  text_payload like "GET %/product/L9ECAV7KIM %"
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

-- 4. Count how many sessions end up with checkout
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
  JSON_VALUE(json_payload.session);

-- 5. Count requests by HTTP status code
SELECT
  JSON_VALUE(json_payload['http.resp.status']) AS status_code,
  COUNT(*) AS request_count
FROM
  `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
  JSON_VALUE(json_payload['http.resp.status']) IS NOT NULL
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 6 HOUR)
GROUP BY
  status_code
ORDER BY
  request_count DESC;

-- 6. Top 10 slowest endpoints
SELECT
  JSON_VALUE(json_payload['http.req.path']) AS endpoint,
  AVG(CAST(JSON_VALUE(json_payload, '$."http.resp.took_ms"') AS INT64)) AS avg_latency_ms,
  COUNT(*) AS request_count
FROM
  `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
  JSON_VALUE(json_payload['http.req.path']) IS NOT NULL
  AND CAST(JSON_VALUE(json_payload, '$."http.resp.took_ms"') AS INT64) IS NOT NULL
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
GROUP BY
  endpoint
HAVING
  request_count > 10
ORDER BY
  avg_latency_ms DESC
LIMIT
  10;

-- 7. Error rate by service
SELECT
  JSON_VALUE(resource.labels.container_name) AS service,
  COUNT(*) AS total_logs,
  COUNTIF(severity = "ERROR") AS error_count,
  SAFE_DIVIDE(COUNTIF(severity = "ERROR"), COUNT(*)) * 100 AS error_rate_percent
FROM
  `PROJECT_ID.global.day2ops-log._AllLogs`
WHERE
  timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  AND JSON_VALUE(resource.labels.container_name) IS NOT NULL
GROUP BY
  service
ORDER BY
  error_rate_percent DESC;

-- 8. User sessions with cart abandonment (added items but never checked out)
WITH user_actions AS (
  SELECT
    JSON_VALUE(json_payload.session) AS session_id,
    COUNTIF(JSON_VALUE(json_payload['http.req.path']) LIKE '/cart/add%') AS cart_adds,
    COUNTIF(JSON_VALUE(json_payload['http.req.path']) = '/cart/checkout' 
            AND JSON_VALUE(json_payload['http.req.method']) = 'POST') AS checkouts
  FROM
    `PROJECT_ID.global.day2ops-log._AllLogs`
  WHERE
    JSON_VALUE(json_payload.session) IS NOT NULL
    AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  GROUP BY
    session_id
)
SELECT
  session_id,
  cart_adds,
  checkouts,
  CASE
    WHEN cart_adds > 0 AND checkouts = 0 THEN TRUE
    ELSE FALSE
  END AS abandoned_cart
FROM
  user_actions
WHERE
  cart_adds > 0
ORDER BY
  cart_adds DESC;
