# Because mylearning is not an HTTP service, you don’t 
# expose /metrics here. 
# Instead, you can:
#   - Export Prometheus counters for core functions.
#   - If mylearning runs inside myapp, metrics will 
#     show up in myapp’s /metrics.
#   - Since both myapp and mylearning metrics use the 
#     same default REGISTRY, you only need to ensure 
#     that mylearning.metrics is imported before you 
#     scrape
#   - If you run a separate service around mylearning later, 
#     you can reuse the same metrics.
from prometheus_client import Counter, Histogram

FIB_CALLS = Counter(
    "mylearning_fib_calls_total",
    "Total calls to fib()",
    ["status"],  # "ok" or "error"
)

FIB_DURATION = Histogram(
    "mylearning_fib_duration_seconds",
    "Time spent inside fib()",
    buckets=(0.0001, 0.001, 0.01, 0.1, 1),
)