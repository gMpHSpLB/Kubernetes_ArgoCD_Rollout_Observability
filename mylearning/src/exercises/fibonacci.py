# Add docstrings
import logging
import time
from typing import List
# When mylearning runs within myapp, you can import 
# these metrics in myapp.metrics and include them in 
# the same registry (or rely on the default REGISTRY). 
# Then they will be visible on /metrics under names 
# like mylearning_fib_calls_total. 
# Prometheus docs: this pattern (library metrics exported 
# via shared registry) is standard
from .metrics import FIB_CALLS, FIB_DURATION
from .tracing import tracer

logger = logging.getLogger(__name__)

def fibonacci(n: int) -> List[int]:
    """
    Compute nth Fibonacci number.

    Args:
        n (int): position

    Returns:
        int: fibonacci value
    """
    start = time.perf_counter()
    try:
        if n < 0:
            FIB_CALLS.labels(status="error").inc()
            logger.warning("fib called with negative input", extra={"n":n})
            raise ValueError("n must be non-negative")
        
        logger.info("fib start",extra={"n":n})
        a, b = 0, 1
        result = []

        with tracer.start_as_current_span("mylearning.fib") as span:
            span.set_attribute("fib.n", n)
            for _ in range(n):
                result.append(a)
                a, b = b, a + b
        
            logger.info("fib end", extra={"n":n, "result":a})
            FIB_CALLS.labels(status="ok").inc()
            return result
    finally:
        FIB_DURATION.observe(time.perf_counter() - start)
