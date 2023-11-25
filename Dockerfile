# first stage
ARG GEM_IMAGE=registry.gitlab.com/abairt/web-application:master

FROM ${GEM_IMAGE} as gem-cache
FROM ruby:3.0-slim as builder
USER root
ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
RUN \
  apt update && apt install -y \
    acl \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    default-libmysqlclient-dev \
    ffmpeg \
    g++ \
    gcc \
    ghostscript \
    git \
    gosu \
    gzip \
    imagemagick \
    libaudit1 \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-regex-dev \
    libbz2-1.0 \
    libc6 \
    libcap-ng0 \
    libcom-err2 \
    libcurl4 \
    libgcc1 \
    libgcrypt20 \
    libgd-dev \
    libgmp-dev \
    libgmp10 \
    libgnutls30 \
    libgpg-error0 \
    libgssapi-krb5-2 \
    libid3tag0 \
    libid3tag0-dev \
    libidn2-0 \
    libjemalloc2 \
    libk5crypto3 \
    libkeyutils1 \
    libkrb5-3 \
    libkrb5support0 \
    libldap-2.4-2 \
    liblzma5 \
    libmad0 \
    libmad0-dev \
    libmariadb3 \
    libncurses6 \
    libncursesw6 \
    libnghttp2-14 \
    libp11-kit0 \
    libpam0g \
    libpq5 \
    libpsl5 \
    libreadline-dev \
    librtmp1 \
    libsasl2-2 \
    libsndfile1 \
    libsndfile1-dev \
    libsqlite3-0 \
    libsqlite3-dev \
    libssh2-1 \
    libssl-dev \
    libssl1.1 \
    libstdc++6 \
    libtasn1-6 \
    libtinfo6 \
    libunistring2 \
    libxml2 \
    libxml2-dev \
    libxslt1-dev \
    make \
    netcat \
    netcat-traditional \
    nodejs \
    npm \
    pkg-config \
    procps \
    sqlite3 \
    sqlite3 \
    sudo \
    tar \
    unzip \
    wget \
    wget \
    yui-compressor \
    zlib1g \
    zlib1g-dev

RUN \
  git clone https://github.com/bbc/audiowaveform.git && \
  cd audiowaveform && \
  wget https://github.com/google/googletest/archive/release-1.12.1.tar.gz && \
  tar xzf release-1.12.1.tar.gz && \
  ln -s googletest-release-1.12.1 googletest && \
  mkdir build && \
  cd build && \
  cmake .. && \
  make package && \
  ln -s /audiowaveform/build/audiowaveform /usr/local/bin/audiowaveform

COPY . /app
COPY --from=gem-cache /app/vendor/bundle /app/vendor/bundle
WORKDIR /app

# Run bundle commands conditionally based on RAILS_ENV
RUN \
  if [ "$RAILS_ENV" = "production" ]; then \
    echo "Deploy build setup!" \
    bundle config set deployment 'true' && \
    bundle config set without 'development test'; \
  fi

RUN \
  bundle install && \
  npm install && \
  SECRET_KEY_BASE=1 bin/rails tailwindcss:build && \
  SECRET_KEY_BASE=1 bin/rails assets:precompile

# second stage
FROM ruby:3.0-slim as prod
COPY --from=builder /app/ /app/
COPY --from=builder --chmod=777 /audiowaveform/build/audiowaveform /usr/local/bin/audiowaveform
RUN apt update && apt install -y \
  ffmpeg \
  libboost-filesystem-dev \
  libboost-program-options-dev \
  libboost-regex-dev \
  libgd-dev \
  libid3tag0 \
  libmad0 \
  libsndfile1 \
  sqlite3
RUN useradd -r -u 1001 -g root nonroot
RUN chown -R nonroot /app
USER nonroot
WORKDIR /app
EXPOSE 3000
ENV RAILS_ENV="production"
CMD ["bin/rails", "server"]