# Base stage for common dependencies
FROM python:3.9-slim as base

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

WORKDIR /usr/local/src

# --- Stage for amd64 Build ---
FROM base as builder-amd64
WORKDIR /usr/local/src
RUN git clone https://github.com/openvenues/libpostal
WORKDIR /usr/local/src/libpostal
RUN git checkout tags/v1.0.0
# Build with SSE flags
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \
    make -j$(nproc) CFLAGS="-O2 -fPIC -mfpmath=sse -msse2 -DUSE_SSE" && \
    make install && ldconfig

# --- Stage for arm64 Build ---
FROM base as builder-arm64
WORKDIR /usr/local/src
RUN git clone https://github.com/openvenues/libpostal
WORKDIR /usr/local/src/libpostal
RUN git checkout tags/v1.0.0
# Build *without* SSE flags
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \
    make -j$(nproc) CFLAGS="-O2 -fPIC" && \
    make install && \
    ldconfig

# --- Final Stage: Combine Artifacts ---
FROM python:3.9-slim

# Copy from amd64 builder
COPY --from=builder-amd64 /usr/local/lib/ /usr/local/lib/
COPY --from=builder-amd64 /usr/local/include/ /usr/local/include/
COPY --from=builder-amd64 /usr/local/share/ /usr/local/share/
COPY --from=builder-amd64 /usr/local/data/ /usr/local/data/

# Copy from arm64 builder
COPY --from=builder-arm64 /usr/local/lib/ /usr/local/lib/
COPY --from=builder-arm64 /usr/local/include/ /usr/local/include/
COPY --from=builder-arm64 /usr/local/share/ /usr/local/share/
COPY --from=builder-arm64 /usr/local/data/ /usr/local/data/

# Install runtime dependencies, nginx and curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        ca-certificates \
        curl \
        gosu \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -d /home/libpostaluser -s /bin/bash libpostaluser
USER libpostaluser

# Download specific model files (in the final stage)
RUN mkdir -p /usr/local/data/libpostal
RUN curl -L -o /usr/local/data/libpostal/address_expansions.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/address_expansions.dat && \
    curl -L -o /usr/local/data/libpostal/language_classifier.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/language_classifier.dat && \
    curl -L -o /usr/local/data/libpostal/language_classifier_keys.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/language_classifier_keys.dat && \
    curl -L -o /usr/local/data/libpostal/near_dupe_hashes_tfrecords.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/near_dupe_hashes_tfrecords.dat  && \
    curl -L -o /usr/local/data/libpostal/numex_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/numex_trie.dat && \
    curl -L -o /usr/local/data/libpostal/osm_ids.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/osm_ids.dat  && \
    curl -L -o /usr/local/data/libpostal/parser_tf_models.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/parser_tf_models.dat && \
    curl -L -o /usr/local/data/libpostal/parser_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/parser_trie.dat && \
    curl -L -o /usr/local/data/libpostal/transliteration_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/transliteration_trie.dat

# Configure nginx
COPY --chown=www-data:www-data nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /usr/share/nginx/html && \
    chown -R www-data:www-data /usr/share/nginx/html

# Switch back to root for setting permissions and setting up entrypoint
USER root

# Set up entrypoint that switches to non-root user
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

HEALTHCHECK CMD curl --fail http://localhost/ || exit 1