# Builder stage
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
WORKDIR /usr/local/src

# Clone and build libpostal
RUN git clone https://github.com/openvenues/libpostal && \
    cd libpostal && \
    git checkout tags/v1.0.0

# Build libpostal (using WORKDIR and -j$(nproc))
WORKDIR /usr/local/src/libpostal
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \
    make -j$(nproc) CFLAGS="-O2 -fPIC" && \
    make install && \
    ldconfig

# Download specific model files (BEST PRACTICE)
RUN mkdir -p /usr/local/data/libpostal
RUN curl -L -o /usr/local/data/libpostal/address_expansions.dat https://data.openvenues.com/libpostal/address_expansions.dat && \
    curl -L -o /usr/local/data/libpostal/language_classifier.dat https://data.openvenues.com/libpostal/language_classifier.dat && \
    curl -L -o /usr/local/data/libpostal/language_classifier_keys.dat https://data.openvenues.com/libpostal/language_classifier_keys.dat && \
    curl -L -o /usr/local/data/libpostal/near_dupe_hashes_tfrecords.dat https://data.openvenues.com/libpostal/near_dupe_hashes_tfrecords.dat  && \
    curl -L -o /usr/local/data/libpostal/numex_trie.dat https://data.openvenues.com/libpostal/numex_trie.dat && \
    curl -L -o /usr/local/data/libpostal/osm_ids.dat https://data.openvenues.com/libpostal/osm_ids.dat  && \
    curl -L -o /usr/local/data/libpostal/parser_tf_models.dat https://data.openvenues.com/libpostal/parser_tf_models.dat && \
    curl -L -o /usr/local/data/libpostal/parser_trie.dat https://data.openvenues.com/libpostal/parser_trie.dat && \
    curl -L -o /usr/local/data/libpostal/transliteration_trie.dat https://data.openvenues.com/libpostal/transliteration_trie.dat

# Final stage
FROM python:3.9-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user and directories
RUN useradd -m -d /home/webuser -s /bin/bash webuser && \
    mkdir -p /usr/share/nginx/html && \
    chown -R webuser:webuser /usr/share/nginx/html

# Copy files from builder *with correct ownership and trailing slashes*
COPY --from=builder --chown=webuser:webuser /usr/local/lib/libpostal.so* /usr/local/lib/
COPY --from=builder --chown=webuser:webuser /usr/local/include/libpostal/ /usr/local/include/libpostal/
COPY --from=builder --chown=webuser:webuser /usr/local/share/libpostal/ /usr/local/share/libpostal/
COPY --from=builder --chown=webuser:webuser /usr/local/data/ /usr/local/data/

# Configure nginx
COPY --chown=www-data:www-data nginx.conf /etc/nginx/nginx.conf

# Switch to root user for entrypoint
USER root

# Set up entrypoint
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]