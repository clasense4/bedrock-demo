# Use Python 3.12 base image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Expose port 8000
EXPOSE 8000

# Run FastAPI app with uvicorn
CMD ["uvicorn", "src.backend.fastapi_app:app", "--host", "0.0.0.0", "--port", "8000"]
