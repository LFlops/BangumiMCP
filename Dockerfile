# Stage 1: Build the application wheel
FROM python:3.10-slim AS builder

# Install uv
RUN pip install uv

# Set the working directory
WORKDIR /app

# Copy only necessary files for dependency installation to leverage Docker cache
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv pip sync --system pyproject.toml

# Copy the rest of the application source code
COPY . .

# Build the wheel
RUN uv build --out-dir /wheels


# Stage 2: Create the final, clean production image
FROM python:3.10-slim

# Install uv (needed to install the wheel)
RUN pip install uv

# Set the working directory
WORKDIR /app

# Copy the built wheel from the builder stage
COPY --from=builder /wheels/*.whl .

# Install the application from the wheel
# This also installs its dependencies as defined in the wheel
RUN uv pip install --system *.whl

# Set default environment variables.
# These can be overridden at runtime (e.g., with `docker run -e ...`)
# It's important NOT to hardcode secrets here.

# Define the command to run the application
# This will execute the 'okx-agent' script installed by the wheel
CMD ["bangumi-tv"]