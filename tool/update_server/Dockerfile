FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.11.32 /uv /uvx /bin/
WORKDIR /app
RUN useradd --uid 10001 --create-home updater && mkdir /data && chown updater /data
COPY pyproject.toml uv.lock .python-version /app/
COPY vocechat_update /app/vocechat_update
RUN uv sync --locked --no-dev --no-cache --no-python-downloads
USER updater
ENV UPDATE_HOST=0.0.0.0 UPDATE_PORT=8080 UPDATE_DB=/data/releases.sqlite3
EXPOSE 8080
CMD ["uv", "run", "--frozen", "--no-sync", "vocechat-update-server"]
