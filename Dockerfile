# syntax=docker/dockerfile:1.4

# ----------------------------------------------------------------------------------------------- #

ARG BUILDER_IMAGE=hexpm/elixir:1.14.2-erlang-25.2-debian-bullseye-20221004-slim
ARG RUNNER_IMAGE=debian:bullseye-20221004-slim

# ----------------------------------------------------------------------------------------------- #

FROM ${BUILDER_IMAGE} AS builder

ENV MIX_ENV=prod

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
    && apt-get clean \
    && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix do local.hex --force, local.rebar --force

COPY --link mix.exs ./
COPY --link lib lib
COPY --link rel rel

RUN --mount=type=cache,target=deps,sharing=locked \
    --mount=type=cache,target=_build,sharing=locked \
    mix deps.get --only ${MIX_ENV} \
    && mix deps.compile \
    && mix compile \
    && mix release \
    && cp -r _build/${MIX_ENV}/rel /

# ----------------------------------------------------------------------------------------------- #

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        libncurses5 \
        libstdc++6 \
        locales \
        openssl \
    && apt-get clean \
    && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

COPY --link --from=builder /rel ./

CMD /app/protohackers/bin/protohackers start

# ----------------------------------------------------------------------------------------------- #
