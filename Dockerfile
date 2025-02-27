# Builder stage
FROM python:3.9-slim AS builder

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

# Create a comprehensive patch to disable all SSE code
RUN echo '#!/bin/bash\n\
# Patch scanner.c to completely disable SSE\n\
sed -i "s/#ifdef USE_SSE/#if 0 \/* Disabled SSE for cross-platform compatibility *\//g" src/scanner.c\n\
\n\
# Create a wrapper for gcc to filter out SSE flags\n\
cat > /tmp/gcc-wrapper << "EOF"\n\
#!/bin/sh\n\
filtered_args=$(echo "$@" | sed "s/-mfpmath=sse//g; s/-msse[0-9]*//g; s/-DUSE_SSE//g")\n\
exec gcc $filtered_args\n\
EOF\n\
chmod +x /tmp/gcc-wrapper\n\
cp /tmp/gcc-wrapper /tmp/g++\n\
export PATH="/tmp:$PATH"\n\
\n\
# Run the actual build with safe flags\n\
./bootstrap.sh\n\
\n\
# Find and patch configure scripts to remove SSE flags\n\
find . -name "configure" -o -name "*.ac" -o -name "*.am" -o -name "*.in" | xargs sed -i "s/-mfpmath=sse//g; s/-msse[0-9]*//g; s/-DUSE_SSE//g"\n\
\n\
# Configure with safe options\n\
./configure --datadir=/usr/local/data \\\n\
            --prefix=/usr/local \\\n\
            --disable-static \\\n\
            --enable-shared \\\n\
            CFLAGS="-O2 -fPIC" \\\n\
            CPPFLAGS="-O2 -fPIC" \\\n\
            CXXFLAGS="-O2 -fPIC"\n\
\n\
# Patch all Makefiles after configure\n\
find . -name "Makefile" | xargs sed -i "s/-mfpmath=sse//g; s/-msse[0-9]*//g; s/-DUSE_SSE//g"\n\
\n\
# Build with safe flags\n\
make -j$(nproc) CFLAGS="-O2 -fPIC" CPPFLAGS="-O2 -fPIC" CXXFLAGS="-O2 -fPIC"\n\
\n\
# Install\n\
make install\n\
ldconfig\n\
' > /tmp/build-script.sh && \
    chmod +x /tmp/build-script.sh && \
    /tmp/build-script.sh

# Download specific model files in builder stage
RUN mkdir -p /usr/local/data/libpostal && \
    curl -L -o /usr/local/data/libpostal/address_expansions.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/address_expansions.dat && \
    curl -L -o /usr/local/data/libpostal/language_classifier.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/language_classifier.dat && \
    curl -L -o /usr/local/data/libpostal/language_classifier_keys.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/language_classifier_keys.dat && \
    curl -L -o /usr/local/data/libpostal/near_dupe_hashes_tfrecords.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/near_dupe_hashes_tfrecords.dat && \
    curl -L -o /usr/local/data/libpostal/numex_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/numex_trie.dat && \
    curl -L -o /usr/local/data/libpostal/osm_ids.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/osm_ids.dat && \
    curl -L -o /usr/local/data/libpostal/parser_tf_models.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/parser_tf_models.dat && \
    curl -L -o /usr/local/data/libpostal/parser_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/parser_trie.dat && \
    curl -L -o /usr/local/data/libpostal/transliteration_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/transliteration_trie.dat

# Final stage
FROM python:3.9-slim

# Copy from builder
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/include/ /usr/local/include/
COPY --from=builder /usr/local/share/ /usr/local/share/
COPY --from=builder /usr/local/data/ /usr/local/data/

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/* && \
    ldconfig

# No ENTRYPOINT or CMD - this is just a builder image