# Ultra-minimal production image using distroless
# Builder stage
FROM python:3.12-slim-bookworm AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install dependencies
COPY pyproject.toml uv.lock README.md ./
RUN pip install uv && uv pip install --system --no-cache -e .

# Copy application
COPY src/ ./src/
COPY alembic.ini migrations/ ./

# Download NLTK data
RUN python -m nltk.downloader -d /nltk_data \
    punkt stopwords wordnet averaged_perceptron_tagger || true

# Runtime stage: Distroless Python image (most secure)
FROM gcr.io/distroless/python3-debian12:nonroot

# Copy Python packages and app from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /build/src /app/src
COPY --from=builder /build/pyproject.toml /build/README.md /app/
COPY --from=builder /build/alembic.ini /app/
COPY --from=builder /build/migrations /app/migrations
COPY --from=builder /nltk_data /nltk_data

# Set environment
ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages:/app \
    PYTHONUNBUFFERED=1 \
    NLTK_DATA=/nltk_data

WORKDIR /app

# Distroless images run as non-root by default
# No shell, no package manager, minimal attack surface
EXPOSE 8000

# Entrypoint for distroless (no shell available)
ENTRYPOINT ["python", "-m", "uvicorn"]
CMD ["src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
