FROM python:3.9-slim as builder

# Install build dependencies with git configuration
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
        nginx \
    && rm -rf /var/lib/apt/lists/* \
    && git config --global http.sslVerify false

# Create directories
RUN mkdir -p /usr/local/data && \
    mkdir -p /usr/local/share/libpostal

# Clone libpostal repository with retries
RUN for i in 1 2 3; do \
        git clone --depth 1 --branch v1.1.0 https://github.com/openvenues/libpostal && break || sleep 15; \
    done

# Copy data files from cloned repository
RUN cp /libpostal/data/language_classifier.dat /usr/local/share/libpostal/ && \
    cp /libpostal/data/parser/address_dictionary.dat /usr/local/share/libpostal/

# Build libpostal in stages
WORKDIR /libpostal
RUN ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \
                --prefix=/usr/local \
                --disable-data-download \
                --disable-static \
                --enable-shared

# Build with optimizations
RUN make CFLAGS="-O2 -fPIC" -j4 && \
    make install && \
    ldconfig

# Package only required files
RUN mkdir -p /usr/share/nginx/html && \
    tar czf /usr/share/nginx/html/libpostal-artifacts.tar.gz \
        /usr/local/lib/libpostal.so* \
        /usr/local/include/libpostal \
        /usr/local/share/libpostal/*.dat

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]