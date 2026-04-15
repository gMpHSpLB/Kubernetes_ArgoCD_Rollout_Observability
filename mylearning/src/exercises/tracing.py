"""
Traces (OpenTelemetry) for mylearning
    Again, mylearning doesn’t own the service boundary. The pattern is:

    Let the service (myapp) set up OTEL.
        In mylearning, only use trace.get_tracer and
        create spans as needed.
"""

from opentelemetry import trace

tracer = trace.get_tracer("mylearning")
