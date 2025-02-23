# Build stage
FROM python:3.9-slim as builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        make \
        python3-dev \
        curl \
        git \
        ca-certificates \
        autoconf \
        automake \
        libtool \
        pkg-config \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Create directories
RUN mkdir -p /usr/local/data && \
    mkdir -p /usr/local/share/libpostal

# Clone and build libpostal
RUN git clone https://github.com/openvenues/libpostal && \
    cd libpostal && \
    git checkout tags/v1.0.0

# Build libpostal
WORKDIR /build/libpostal
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \
    make download-models && \
    make CFLAGS="-O2 -fPIC" -j4 && \
    make install && \
    ldconfig

# Final stage
FROM python:3.9-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        libgcc1 \
        libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -r -s /bin/false webuser && \
    mkdir -p /usr/share/nginx/html && \
    chown -R webuser:webuser /usr/share/nginx/html

# Copy files from builder
COPY --from=builder /usr/local/lib/libpostal.so* /usr/local/lib/
COPY --from=builder /usr/local/include/libpostal /usr/local/include/libpostal
COPY --from=builder /usr/local/share/libpostal /usr/local/share/libpostal
COPY --from=builder /usr/local/data /usr/local/data

# Run ldconfig after copying shared libraries
RUN ldconfig

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Switch to non-root user
USER webuser

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/libpostal-artifacts.tar.gz || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]