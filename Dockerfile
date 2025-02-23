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
        wget \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /usr/local/data && \
    mkdir -p /usr/local/share/libpostal

# Download minimal required data files
RUN wget -q https://raw.githubusercontent.com/openvenues/libpostal/master/data/language_classifier.dat -O /usr/local/share/libpostal/language_classifier.dat && \
    wget -q https://raw.githubusercontent.com/openvenues/libpostal/master/data/parser/address_dictionary.dat -O /usr/local/share/libpostal/address_dictionary.dat

# Clone libpostal repository with minimal depth
RUN git clone --depth 1 --branch v1.1.0 https://github.com/openvenues/libpostal

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