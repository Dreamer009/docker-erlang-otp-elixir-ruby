FROM node:8-alpine as scripts

ENV RUBY_BASE_VERSION=2.5 \
  RUBY_BRANCH=master \
  ELIXIR_BASE_VERSION=1.9 \
  ELIXIR_BRANCH=master \
  ERLANG_BASE_VERSION=22 \
  ERLANG_BRANCH=master

RUN mkdir /scripts
WORKDIR /scripts

# Fetch Dockerfiles
ADD "https://raw.githubusercontent.com/c0b/docker-erlang-otp/${ERLANG_BRANCH}/${ERLANG_BASE_VERSION}/Dockerfile" /scripts/Dockerfile-erlang
ADD "https://raw.githubusercontent.com/c0b/docker-elixir/${ELIXIR_BRANCH}/${ELIXIR_BASE_VERSION}/Dockerfile" /scripts/Dockerfile-elixir
ADD "https://raw.githubusercontent.com/docker-library/ruby/${RUBY_BRANCH}/${RUBY_BASE_VERSION}/buster/Dockerfile" /scripts/Dockerfile-ruby

ADD package.json .
ADD index.js .
ADD yarn.lock .

RUN yarn install

# Copy the conntents of Dockerfiles to a bash script
RUN node index.js > install.sh

# Release Image
FROM buildpack-deps:buster

# Copy in bash script from above
COPY --from=scripts /scripts/install.sh /install.sh

ENV GEM_HOME /usr/local/bundle
ENV LANG=C.UTF-8 \
  BUNDLE_PATH="$GEM_HOME" \
  BUNDLE_BIN="$GEM_HOME/bin" \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH

# Run the contents of the Dockerfiles
RUN bash install.sh

# Customizations

RUN mix local.hex --force \
  && mix local.rebar --force \
  && runtimeDeps='ca-certificates' \
  && apt-get update \
  && apt-get install -y --no-install-recommends $runtimeDeps \
  && rm -rf /var/lib/apt/lists/*

CMD ["iex"]
