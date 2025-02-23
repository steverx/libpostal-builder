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

# Clone libpostal repository
RUN git clone https://github.com/openvenues/libpostal

WORKDIR /usr/local/src/libpostal

RUN git checkout tags/v1.0.0

# Use TARGETPLATFORM for conditional compilation
ARG TARGETPLATFORM

# Build libpostal (Conditional CFLAGS within the RUN instruction)
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \
    if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        make -j$(nproc) CFLAGS="-O2 -fPIC -mfpmath=sse -msse2 -DUSE_SSE"; \
    else \
        make -j$(nproc) CFLAGS="-O2 -fPIC"; \
    fi && \
    make install && \
    ldconfig

# Download specific model files
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