FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone dirty-waters
RUN git clone https://github.com/chains-project/dirty-waters.git
WORKDIR /app/dirty-waters

# Create cache directory with proper permissions
RUN mkdir -p tool/cache && chmod 777 tool/cache
RUN cp -r /cache tool/cache

# Install dirty-waters and its dependencies
RUN pip install -r requirements.txt

# Create entrypoint script
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/app/dirty-waters/entrypoint.sh"]
