# Training example: pin the base image by digest for a production release.
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app app

COPY --chown=app:app app.py ./app.py
USER app
EXPOSE 8000

# Do not bake credentials into the image. Inject them at runtime.
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
