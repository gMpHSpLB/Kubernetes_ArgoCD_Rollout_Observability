# # This file is a Helm values override for deploying a Loki 
# logging stack in Kubernetes, most likely for a dev environment. 
# It configures Loki to store logs locally in the cluster, 
# keeps retention short, and enables Promtail to ship pod 
# logs into Loki. Loki is a log aggregation system designed 
# to collect and query logs with low indexing overhead, and 
# Promtail is the agent that reads logs from Kubernetes 
# nodes/pods and pushes them to Loki.
# #
# # What it is for
# # This kind of file is used when installing or upgrading 
# the loki-stack Helm chart. Instead of using the chart’s 
# default settings, you provide a custom YAML file to control
#  how Loki, Grafana, and Promtail behave in your environment. In your case, the file looks tuned for development: single replica, filesystem storage, no Grafana, and lightweight resource usage.
# # How it works together
# # The flow is simple: your applications write logs to 
# stdout/stderr, Kubernetes stores them on the node, 
# Promtail tails those logs, and then sends them to Loki for 
# storage and querying. If Grafana were enabled, you could 
# browse and filter the logs in a dashboard. With this file, 
# the setup is intentionally lightweight and suitable for 
# local development, testing, or a small internal cluster.
# #
# # Practical use case
# # This is useful when you want centralized logs for multiple 
# pods without running a heavy logging backend. For example,
#  if your Python API crashes in Kubernetes, you can query 
#  its logs in Loki instead of SSH’ing into nodes or reading 
#  pod logs manually. For a dev environment, the filesystem 
#  storage and 7-day retention keep things easy to manage,
#   but for production you would usually move to more durable 
#   storage and stronger access controls.
global:
  environment: dev

loki: # This begins the configuration block for Loki itself, the backend log storage and query service.
  auth_enabled: false # Disables authentication inside Loki. This is common in a dev or internal cluster setup, but it is not something you would normally want exposed in production.
  commonConfig: # Shared settings that apply across Loki components.
    replication_factor: 1 # Tells Loki to keep only one copy of each log chunk. This is fine for a single-node or dev setup, but it means no redundancy if a pod or node fails.
  storage: # Defines where Loki stores log data
    type: filesystem # Uses the local filesystem instead of object storage like S3, GCS, or Azure Blob. This is simpler and cheaper for local testing, but not ideal for scalable production use.
  schemaConfig: # Defines how Loki organizes and indexes log data over time
    configs: # A list of schema periods. Loki can change schemas as your cluster evolves
      - from: "2020-10-24" # Applies this schema configuration starting from the given date
        store: boltdb-shipper # Uses the BoltDB shipper storage model, which stores index files in a way that can be shipped alongside chunks. This is an older but still commonly seen Loki setup for simpler deployments.
        object_store: filesystem # Says the stored chunks/index data should live on the local filesystem.
        schema: v11 # Selects Loki schema version 11, which defines the layout and behavior for how logs are indexed and queried
        index: # Settings for the index files that help Loki find log streams quickly.
          prefix: index_ # Prefix used for index file names
          period: 24h # Creates a new index period every 24 hours. This helps segment data by day.
  compactor: # Configures Loki’s compactor component, which helps manage retention and cleanup
    retention_enabled: true # Turns on log retention enforcement, meaning Loki will delete old logs according to policy
    delete_request_store: filesystem # Stores delete requests on the filesystem. This is tied to retention and deletion operations
    retention_delete_delay: 2h # Waits 2 hours before actually deleting data after it becomes eligible for deletion. This gives time for internal processing and safety
    retention_interval: 5m # Runs retention cleanup every 5 minutes
  limits_config: # Defines cluster-wide limits and policy settings
    retention_period: 7d # Keeps logs for 7 days, then deletes them. That makes sense for dev because it limits disk usage

grafana: # Configuration block for Grafana, the dashboard/UI component.
  enabled: false # Disables Grafana in this deployment. That means this stack is only setting up Loki and Promtail, not the UI for browsing logs. This is useful if you already have Grafana installed elsewhere or you only want log collection

promtail: # Configuration for Promtail, the log shipping agent.
  enabled: true # Enables Promtail so logs are collected and pushed into Loki. This is the component that reads container logs and forwards them
  resources: # Sets Kubernetes resource requests and limits for the Promtail pod
    requests: # Minimum guaranteed resources the scheduler should reserve
      cpu: "50m" # Requests 0.05 CPU cores
      memory: "128Mi" # Requests 128 MiB memory
    limits: # Maximum resources Promtail can use
      cpu: "200m" # Caps CPU usage at 0.2 cores
      memory: "256Mi" # Caps memory at 256 MiB
  config: # Promtail-specific runtime config
    clients: # Defines where Promtail sends logs
      - url: http://myapp-logging-dev-loki.logging.svc:3100/loki/api/v1/push # Promtail pushes log streams to Loki’s HTTP push endpoint on port 3100. In Kubernetes, http://loki usually resolves to the Loki service name in the same namespace.