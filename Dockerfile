FROM python:3.9-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc g++ make python3-dev curl git ca-certificates \
        autoconf automake libtool pkg-config build-essential patch \
    && rm -rf /var/lib/apt/lists/*

# Create build script with proper line endings
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Remove SSE flags from configure.ac before bootstrap\n\
sed -i "/CFLAGS.*mfpmath=sse/d" configure.ac\n\
sed -i "/CFLAGS.*msse2/d" configure.ac\n\
sed -i "/USE_SSE=yes/d" configure.ac\n\
\n\
# Bootstrap and configure without SSE\n\
./bootstrap.sh\n\
CFLAGS="-O2 -fPIC" ./configure \\\n\
    --datadir=/usr/local/data \\\n\
    --prefix=/usr/local \\\n\
    --disable-static \\\n\
    --enable-shared \\\n\
    --disable-sse\n\
\n\
# Build and install\n\
make -j$(nproc)\n\
make install\n\
ldconfig' > /usr/local/bin/build-libpostal.sh && \
    chmod +x /usr/local/bin/build-libpostal.sh

# --- Stage for amd64 Build ---
FROM base AS builder-amd64
WORKDIR /usr/local/src
RUN git clone https://github.com/openvenues/libpostal
WORKDIR /usr/local/src/libpostal
RUN git checkout tags/v1.0.0
RUN /usr/local/bin/build-libpostal.sh

# --- Stage for arm64 Build ---
FROM base AS builder-arm64
WORKDIR /usr/local/src
RUN git clone https://github.com/openvenues/libpostal
WORKDIR /usr/local/src/libpostal
RUN git checkout tags/v1.0.0
RUN /usr/local/bin/build-libpostal.sh

# --- Final Stage: Combine Artifacts ---
FROM python:3.9-slim

# Copy artifacts from builders
COPY --from=builder-amd64 /usr/local/lib/ /usr/local/lib/
COPY --from=builder-amd64 /usr/local/include/ /usr/local/include/
COPY --from=builder-amd64 /usr/local/share/ /usr/local/share/
COPY --from=builder-amd64 /usr/local/data/ /usr/local/data/

COPY --from=builder-arm64 /usr/local/lib/ /usr/local/lib/
COPY --from=builder-arm64 /usr/local/include/ /usr/local/include/
COPY --from=builder-arm64 /usr/local/share/ /usr/local/share/
COPY --from=builder-arm64 /usr/local/data/ /usr/local/data/

# Install runtime dependencies, nginx, and curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nginx \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Create directories and set permissions
RUN mkdir -p /usr/local/data/libpostal /usr/share/nginx/html && \
    useradd -m -d /home/libpostaluser -s /bin/bash libpostaluser && \
    chown -R libpostaluser:libpostaluser /usr/local/data/libpostal && \
    chown -R www-data:www-data /usr/share/nginx/html

# Switch to non-root user and download data files
USER libpostaluser
WORKDIR /usr/local/data/libpostal

# Download data files
RUN curl -L -o address_expansions.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/address_expansions.dat && \
    curl -L -o language_classifier.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/language_classifier.dat && \
    curl -L -o language_classifier_keys.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/language_classifier_keys.dat && \
    curl -L -o near_dupe_hashes_tfrecords.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/near_dupe_hashes_tfrecords.dat && \
    curl -L -o numex_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/numex_trie.dat && \
    curl -L -o osm_ids.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/osm_ids.dat && \
    curl -L -o parser_tf_models.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/parser_tf_models.dat && \
    curl -L -o parser_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/parser_trie.dat && \
    curl -L -o transliteration_trie.dat https://raw.githubusercontent.com/openvenues/libpostal/v1.0.0/data/transliteration_trie.dat

# Configure nginx
USER root
COPY --chown=www-data:www-data nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /usr/share/nginx/html && \
  chown -R www-data:www-data /usr/share/nginx/html

# Switch back to root
USER root
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
HEALTHCHECK CMD curl --fail http://localhost/ || exit 1