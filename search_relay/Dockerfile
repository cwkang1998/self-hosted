FROM python:3.12-slim-bookworm
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/


WORKDIR /app


COPY pyproject.toml /app/pyproject.toml

COPY uv.lock /app/uv.lock

COPY server.py /app/server.py

RUN uv sync --locked

CMD ["uv", "run", "fastapi", "run", "server.py", "--port", "80"]