FROM python:3.13-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends gopass ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY scripts/proxypilot_recover.py /usr/local/bin/proxypilot_recover.py

ENTRYPOINT ["python3", "/usr/local/bin/proxypilot_recover.py"]
