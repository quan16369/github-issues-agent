"""Traced wrapper for agents to add OpenTelemetry spans"""

import time
from functools import wraps
from typing import Any, Callable

from loguru import logger
from opentelemetry import trace

from src.models.agent_models import IssueState


def trace_agent(agent_name: str):
    """
    Decorator to add OpenTelemetry tracing to agent functions
    
    Args:
        agent_name: Name of the agent for the span
    """
    def decorator(func: Callable):
        @wraps(func)
        async def async_wrapper(state: IssueState, *args: Any, **kwargs: Any) -> dict:
            # Get tracer
            try:
                from src.utils.telemetry import get_app_metrics, get_tracer
                
                tracer = get_tracer()
                app_metrics = get_app_metrics()
            except RuntimeError:
                # Telemetry not initialized, run without tracing
                return await func(state, *args, **kwargs)
            
            # Create span for this agent
            with tracer.start_as_current_span(
                f"agent.{agent_name}",
                attributes={
                    "agent.name": agent_name,
                    "issue.title": state.title[:100] if state.title else "N/A",  # Truncate for safety
                    "issue.body_length": len(state.body) if state.body else 0,
                }
            ) as span:
                start_time = time.time()
                
                try:
                    logger.info(f"🔹 Starting agent: {agent_name}")
                    
                    # Execute agent
                    result = await func(state, *args, **kwargs)
                    
                    # Record success metrics
                    duration = time.time() - start_time
                    app_metrics.agent_execution_counter.add(1, {"agent": agent_name, "status": "success"})
                    app_metrics.agent_duration.record(duration, {"agent": agent_name})
                    
                    # Add span attributes
                    span.set_attribute("agent.duration_seconds", duration)
                    span.set_attribute("agent.status", "success")
                    
                    # Check if agent blocked the request
                    if "blocked" in result and result["blocked"]:
                        span.set_attribute("agent.blocked", True)
                        app_metrics.guardrail_blocks_counter.add(1, {"agent": agent_name})
                        logger.warning(f"Agent {agent_name} blocked the request")
                    
                    logger.info(f"Completed agent: {agent_name} ({duration:.3f}s)")
                    
                    return result
                    
                except Exception as e:
                    # Record error metrics
                    duration = time.time() - start_time
                    app_metrics.agent_execution_counter.add(
                        1, 
                        {"agent": agent_name, "status": "error", "error_type": type(e).__name__}
                    )
                    app_metrics.agent_duration.record(duration, {"agent": agent_name})
                    
                    # Add error to span
                    span.set_attribute("agent.status", "error")
                    span.set_attribute("error", True)
                    span.set_attribute("error.type", type(e).__name__)
                    span.set_attribute("error.message", str(e))
                    span.record_exception(e)
                    
                    logger.error(f"Agent {agent_name} failed: {e}")
                    raise
        
        @wraps(func)
        def sync_wrapper(state: IssueState, *args: Any, **kwargs: Any) -> dict:
            # Get tracer
            try:
                from src.utils.telemetry import get_app_metrics, get_tracer
                
                tracer = get_tracer()
                app_metrics = get_app_metrics()
            except RuntimeError:
                # Telemetry not initialized, run without tracing
                return func(state, *args, **kwargs)
            
            # Create span for this agent
            with tracer.start_as_current_span(
                f"agent.{agent_name}",
                attributes={
                    "agent.name": agent_name,
                    "issue.title": state.title[:100] if state.title else "N/A",
                    "issue.body_length": len(state.body) if state.body else 0,
                }
            ) as span:
                start_time = time.time()
                
                try:
                    logger.info(f"🔹 Starting agent: {agent_name}")
                    
                    # Execute agent
                    result = func(state, *args, **kwargs)
                    
                    # Record success metrics
                    duration = time.time() - start_time
                    app_metrics.agent_execution_counter.add(1, {"agent": agent_name, "status": "success"})
                    app_metrics.agent_duration.record(duration, {"agent": agent_name})
                    
                    # Add span attributes
                    span.set_attribute("agent.duration_seconds", duration)
                    span.set_attribute("agent.status", "success")
                    
                    if "blocked" in result and result["blocked"]:
                        span.set_attribute("agent.blocked", True)
                        app_metrics.guardrail_blocks_counter.add(1, {"agent": agent_name})
                        logger.warning(f"Agent {agent_name} blocked the request")
                    
                    logger.info(f"Completed agent: {agent_name} ({duration:.3f}s)")
                    
                    return result
                    
                except Exception as e:
                    # Record error metrics
                    duration = time.time() - start_time
                    app_metrics.agent_execution_counter.add(
                        1,
                        {"agent": agent_name, "status": "error", "error_type": type(e).__name__}
                    )
                    app_metrics.agent_duration.record(duration, {"agent": agent_name})
                    
                    # Add error to span
                    span.set_attribute("agent.status", "error")
                    span.set_attribute("error", True)
                    span.set_attribute("error.type", type(e).__name__)
                    span.set_attribute("error.message", str(e))
                    span.record_exception(e)
                    
                    logger.error(f"Agent {agent_name} failed: {e}")
                    raise
        
        # Return appropriate wrapper based on function type
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator
