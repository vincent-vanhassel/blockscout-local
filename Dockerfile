FROM bitwalker/alpine-elixir-phoenix:1.14 AS builder

WORKDIR /app

COPY ./apk-packages/alpine-sdk.apk /tmp/apk-packages/alpine-sdk.apk
COPY ./apk-packages/gmp-dev.apk /tmp/apk-packages/gmp-dev.apk
COPY ./apk-packages/automake.apk /tmp/apk-packages/automake.apk
COPY ./apk-packages/libtool.apk /tmp/apk-packages/libtool.apk
COPY ./apk-packages/inotify-tools.apk /tmp/apk-packages/inotify-tools.apk
COPY ./apk-packages/autoconf.apk /tmp/apk-packages/autoconf.apk
COPY ./apk-packages/python3.apk /tmp/apk-packages/python3.apk
COPY ./apk-packages/file.apk /tmp/apk-packages/file.apk
COPY ./apk-packages/qemu-x86_64.apk /tmp/apk-packages/qemu-x86_64.apk

RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/alpine-sdk.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/gmp-dev.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/automake.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/libtool.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/inotify-tools.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/autoconf.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/python3.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/file.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/qemu-x86_64.apk

ENV GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc \
    GLIBC_VERSION=2.30-r0 \
    PORT=4000 \
    MIX_ENV="prod" \
    SECRET_KEY_BASE="RMgI4C1HSkxsEjdhtGMfwAHfyT6CKWXOgzCboJflfSm4jeAlic52io05KB6mqzc5"

COPY ./apk-packages/libstdc++.apk /tmp/apk-packages/libstdc++.apk
COPY ./apk-packages/curl.apk /tmp/apk-packages/curl.apk
COPY ./apk-packages/ca-certificates.apk /tmp/apk-packages/ca-certificates.apk
COPY ./apk-packages/glibc-${GLIBC_VERSION}.apk /tmp/apk-packages/glibc-${GLIBC_VERSION}.apk
COPY ./apk-packages/glibc-bin-${GLIBC_VERSION}.apk /tmp/apk-packages/glibc-bin-${GLIBC_VERSION}.apk

RUN set -ex
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/libstdc++.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/curl.apk 
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/ca-certificates.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/glibc-${GLIBC_VERSION}.apk 
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/glibc-bin-${GLIBC_VERSION}.apk
RUN rm -v /tmp/apk-packages/*.apk
RUN /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

ARG CACHE_EXCHANGE_RATES_PERIOD
ARG DISABLE_READ_API
ARG DISABLE_WEBAPP
ARG DISABLE_WRITE_API
ARG CACHE_TOTAL_GAS_USAGE_COUNTER_ENABLED
ARG ADMIN_PANEL_ENABLED
ARG CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL
ARG SESSION_COOKIE_DOMAIN
ARG MIXPANEL_TOKEN
ARG MIXPANEL_URL
ARG AMPLITUDE_API_KEY
ARG AMPLITUDE_URL

ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

RUN mix do deps.get, local.rebar --force, deps.compile

ADD . .

COPY . .

RUN mix compile
# RUN mkdir /npm-packages
# COPY npm-packages/npm.tgz /npm-packages/npm.tgz
COPY npm-packages/.npm /.npm
ENV NPM_CONFIG_CACHE=/.npm
# WORKDIR /npm-packages
# RUN tar -xzf npm.tgz
# RUN npm install -g .

# Add blockscout npm deps

WORKDIR /app/apps/block_scout_web/assets/
RUN npm ci --offline || npm install --offline
RUN npm run deploy
WORKDIR /app/apps/explorer/
RUN npm ci --offline || npm install --offlin
RUN npm run deploy
WORKDIR /app
RUN apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN mix phx.digest

RUN mkdir -p /opt/release
RUN mix release blockscout
RUN mv _build/${MIX_ENV}/rel/blockscout /opt/release

##############################################################
FROM bitwalker/alpine-elixir-phoenix:1.14

ARG RELEASE_VERSION
ENV RELEASE_VERSION=${RELEASE_VERSION}
ARG BLOCKSCOUT_VERSION
ENV BLOCKSCOUT_VERSION=${BLOCKSCOUT_VERSION}

COPY ./apk-packages/jq.apk /tmp/apk-packages/jq.apk
RUN apk add --no-cache --allow-untrusted /tmp/apk-packages/jq.apk

WORKDIR /app

COPY --from=builder /opt/release/blockscout .
COPY --from=builder /app/apps/explorer/node_modules ./node_modules
COPY --from=builder /app/config/config_helper.exs ./config/config_helper.exs
COPY --from=builder /app/config/config_helper.exs /app/releases/${RELEASE_VERSION}/config_helper.exs

