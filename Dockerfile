# Builds a release of the app in the Elixir image and copies it into a slim
# Debian image to run.

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.6
ARG DEBIAN_VERSION=bookworm-20251117-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Dependencies first, so they stay cached while only the code changes.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile

# Changes to the runtime config don't require recompiling the code.
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses5 locales ca-certificates curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"
ENV PORT=4000

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/job_tracker ./

USER nobody

EXPOSE 4000

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

CMD ["/app/bin/docker-entrypoint"]
