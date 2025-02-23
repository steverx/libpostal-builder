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

# Clone libpostal repository and verify filesiles
RUN git clone --depth 1 --branch v1.1.0 https://github.com/openvenues/libpostal && \--branch v1.1.0 https://github.com/openvenues/libpostal && \
    cd libpostal && \
    ls -la data/ && \la data/ && \
    ./bootstrap.sh && \    ./bootstrap.sh && \
    ./configure --datadir=/usr/local/data \a \
                --prefix=/usr/local \
                --disable-static \
                --enable-shared && \                --enable-shared && \
    make download-models && \ \
    make CFLAGS="-O2 -fPIC" -j4 && \O2 -fPIC" -j4 && \
    make install && \
    ldconfig

# Package only required files
RUN mkdir -p /usr/share/nginx/html && \ && \
    tar czf /usr/share/nginx/html/libpostal-artifacts.tar.gz \ml/libpostal-artifacts.tar.gz \
        /usr/local/lib/libpostal.so* \        /usr/local/lib/libpostal.so* \
        /usr/local/include/libpostal \/libpostal \
        /usr/local/share/libpostal

# Configure nginxnginx
COPY nginx.conf /etc/nginx/nginx.confCOPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]