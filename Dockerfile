# first stage
FROM registry.gitlab.com/abairt/web-application:master as gem-cache
FROM bitnami/ruby:3.0-prod as builder
USER root
ENV RAILS_ENV="production"
RUN install_packages acl build-essential ca-certificates curl default-libmysqlclient-dev ghostscript git gzip imagemagick libaudit1 libbz2-1.0 libc6 libcap-ng0 libcom-err2 libcurl4 libffi6 libgcc1 libgcrypt20 libgmp-dev libgmp10 libgnutls30 libgpg-error0 libgssapi-krb5-2 libhogweed4 libicu63 libidn2-0 libjemalloc2 libk5crypto3 libkeyutils1 libkrb5-3 libkrb5support0 libldap-2.4-2 liblzma5 libmariadb3 libncurses6 libncursesw6 libnettle6 libnghttp2-14 libp11-kit0 libpam0g libpq5 libpsl5 libreadline-dev libreadline7 librtmp1 libsasl2-2 libsqlite3-0 libsqlite3-dev libssh2-1 libssl-dev libssl1.1 libstdc++6 libtasn1-6 libtinfo6 libunistring2 libxml2 libxml2-dev libxslt1-dev netcat netcat-traditional pkg-config procps sqlite3 sudo tar unzip wget zlib1g zlib1g-dev nodejs npm git gosu yui-compressor
COPY . /app
COPY --from=gem-cache /app/vendor/bundle /app/vendor/bundle
WORKDIR /app
RUN \
  bundle config set deployment 'true' && \
  bundle config set without 'development test'
RUN \
  bundle install && \
  npm install && \
  SECRET_KEY_BASE=1 bin/rails assets:precompile

# second stage
FROM bitnami/ruby:3.0-prod as prod
COPY --from=builder /app/ /app/
RUN useradd -r -u 1001 -g root nonroot
RUN chown -R nonroot /app
USER nonroot
WORKDIR /app
EXPOSE 3000
ENV RAILS_ENV="production"
CMD ["bin/rails", "server"]