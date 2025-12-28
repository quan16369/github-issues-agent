"""OpenTelemetry configuration and utilities"""

import os
from typing import Optional

from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import start_http_server


def setup_telemetry(
    service_name: str = "github-issue-agent",
    service_version: str = "1.0.0",
    environment: str = "production",
    otlp_endpoint: Optional[str] = None,
    enable_prometheus: bool = True,
    prometheus_port: int = 8001,
) -> tuple[trace.Tracer, metrics.Meter]:
    """
    Setup OpenTelemetry with tracing and metrics
    
    Args:
        service_name: Name of the service
        service_version: Version of the service
        environment: Environment (dev/staging/prod)
        otlp_endpoint: OTLP collector endpoint (defaults to env var or localhost)
        enable_prometheus: Whether to expose Prometheus metrics endpoint
        prometheus_port: Port for Prometheus metrics endpoint
    
    Returns:
        Tuple of (tracer, meter)
    """
    
    # Resource attributes
    resource = Resource.create(
        {
            "service.name": service_name,
            "service.version": service_version,
            "deployment.environment": environment,
        }
    )
    
    # Setup Tracing
    trace_provider = TracerProvider(resource=resource)
    
    # OTLP exporter for traces (to Jaeger via OpenTelemetry Collector)
    otlp_endpoint = otlp_endpoint or os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
    if otlp_endpoint:
        otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
        trace_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
    
    trace.set_tracer_provider(trace_provider)
    
    # Setup Metrics
    metric_readers = []
    
    # Prometheus exporter for metrics
    if enable_prometheus:
        prometheus_reader = PrometheusMetricReader()
        metric_readers.append(prometheus_reader)
        # Start Prometheus HTTP server
        start_http_server(port=prometheus_port, addr="0.0.0.0")
    
    # OTLP exporter for metrics
    if otlp_endpoint:
        otlp_metric_exporter = OTLPMetricExporter(endpoint=otlp_endpoint, insecure=True)
        metric_readers.append(otlp_metric_exporter)
    
    meter_provider = MeterProvider(resource=resource, metric_readers=metric_readers)
    metrics.set_meter_provider(meter_provider)
    
    # Get tracer and meter
    tracer = trace.get_tracer(service_name, service_version)
    meter = metrics.get_meter(service_name, service_version)
    
    # Auto-instrument common libraries
    RequestsInstrumentor().instrument()
    
    return tracer, meter


def instrument_fastapi(app):
    """Instrument FastAPI application"""
    FastAPIInstrumentor.instrument_app(app)


def instrument_sqlalchemy(engine):
    """Instrument SQLAlchemy engine"""
    SQLAlchemyInstrumentor().instrument(engine=engine)


# Custom metrics
class ApplicationMetrics:
    """Custom application metrics"""
    
    def __init__(self, meter: metrics.Meter):
        self.meter = meter
        
        # Issue processing metrics
        self.issues_processed_counter = meter.create_counter(
            name="issues_processed_total",
            description="Total number of issues processed",
            unit="1",
        )
        
        self.issues_failed_counter = meter.create_counter(
            name="issues_failed_total",
            description="Total number of issues that failed processing",
            unit="1",
        )
        
        self.issue_processing_duration = meter.create_histogram(
            name="issue_processing_duration_seconds",
            description="Time taken to process an issue",
            unit="s",
        )
        
        # Agent-specific metrics
        self.agent_execution_counter = meter.create_counter(
            name="agent_executions_total",
            description="Total number of agent executions by type",
            unit="1",
        )
        
        self.agent_duration = meter.create_histogram(
            name="agent_execution_duration_seconds",
            description="Time taken for agent execution by type",
            unit="s",
        )
        
        # OpenAI API metrics
        self.openai_tokens_counter = meter.create_counter(
            name="openai_tokens_consumed_total",
            description="Total OpenAI tokens consumed",
            unit="1",
        )
        
        self.openai_requests_counter = meter.create_counter(
            name="openai_requests_total",
            description="Total OpenAI API requests",
            unit="1",
        )
        
        # Guardrail metrics
        self.guardrail_blocks_counter = meter.create_counter(
            name="guardrail_blocks_total",
            description="Total number of guardrail blocks",
            unit="1",
        )
        
        # Vector search metrics
        self.vector_search_counter = meter.create_counter(
            name="vector_searches_total",
            description="Total number of vector searches",
            unit="1",
        )
        
        self.vector_search_duration = meter.create_histogram(
            name="vector_search_duration_seconds",
            description="Time taken for vector search",
            unit="s",
        )


# Global instances
_tracer: Optional[trace.Tracer] = None
_meter: Optional[metrics.Meter] = None
_app_metrics: Optional[ApplicationMetrics] = None


def get_tracer() -> trace.Tracer:
    """Get the global tracer instance"""
    if _tracer is None:
        raise RuntimeError("Telemetry not initialized. Call setup_telemetry() first.")
    return _tracer


def get_meter() -> metrics.Meter:
    """Get the global meter instance"""
    if _meter is None:
        raise RuntimeError("Telemetry not initialized. Call setup_telemetry() first.")
    return _meter


def get_app_metrics() -> ApplicationMetrics:
    """Get the application metrics instance"""
    if _app_metrics is None:
        raise RuntimeError("Telemetry not initialized. Call setup_telemetry() first.")
    return _app_metrics


def initialize_telemetry(**kwargs):
    """Initialize global telemetry instances"""
    global _tracer, _meter, _app_metrics
    _tracer, _meter = setup_telemetry(**kwargs)
    _app_metrics = ApplicationMetrics(_meter)
    return _tracer, _meter, _app_metrics
