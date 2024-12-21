FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    maven \  # For Maven support
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone dirty-waters
RUN git clone https://github.com/chains-project/dirty-waters.git
WORKDIR /app/dirty-waters

# Install dirty-waters and its dependencies
RUN pip install -r requirements.txt

# Create entrypoint script
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/app/dirty-waters/entrypoint.sh"]
