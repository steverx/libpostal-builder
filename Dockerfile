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
        autoconf \
        automake \
        libtool \
        pkg-config \
        build-essential \
        nginx \
    && rm -rf /var/lib/apt/lists/*

# Create data directory
RUN mkdir -p /usr/local/data

# Clone and build libpostal
RUN git clone --depth 1 https://github.com/openvenues/libpostal && \
    cd libpostal && \
    ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data --prefix=/usr/local && \
    make CFLAGS="-O2 -fPIC" -j$(nproc) && \
    make install && \
    ldconfig

# Create artifact directory and package files
RUN mkdir -p /usr/share/nginx/html && \
    cd /usr/local && \
    tar czf /usr/share/nginx/html/libpostal-artifacts.tar.gz \
        lib/libpostal* \
        include/libpostal \
        data

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]