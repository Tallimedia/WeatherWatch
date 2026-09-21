FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY pyproject.toml ./
# The legal pages are rendered from these at request time.
# Every Markdown file, not a hand-listed pair. Naming them individually
# meant adding the car app's two legal documents shipped an image without
# them, and the only symptom was /privacy returning 404 on one hostname —
# which is the URL Play is given for that app's privacy policy.
COPY *.md ./
COPY app ./app
RUN pip install --no-cache-dir .

# Non-root, matching the VolvoWatch backend's uid so host bind mounts behave
# the same way if any are ever added.
RUN useradd -u 1000 -m appuser
USER appuser

EXPOSE 8791
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s \
    CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8791/healthz').read()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8791"]
