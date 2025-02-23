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

# Build libpostal (using WORKDIR and -j2)
WORKDIR /usr/local/src/libpostal
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \
    make -j2 CFLAGS="-O2 -fPIC" && \
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

# Install runtime