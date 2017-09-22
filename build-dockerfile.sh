#!/bin/bash
set -uef -o pipefail

readonly RUBY_BASE_VERSION=2.4
readonly ELIXIR_BASE_VERSION=1.5
readonly ERLANG_BASE_VERSION=20

function strip_dockerfile() {
	local string="$1"

	echo "${string}" | grep -v "FROM" | grep -v "CMD"
}

function fetch_contents() {
	local url="$1"

	echo "Fetching ${url}" >&2
	curl -s "${url}"
}

function main() {
	local erlang_dockerfile=$(fetch_contents "https://raw.githubusercontent.com/c0b/docker-erlang-otp/master/${ERLANG_BASE_VERSION}/Dockerfile")
	local cleaned_erlang_dockerfile=$(strip_dockerfile "$erlang_dockerfile")

	local elixir_dockerfile=$(fetch_contents "https://raw.githubusercontent.com/c0b/docker-elixir/master/${ELIXIR_BASE_VERSION}/Dockerfile")
	local cleaned_elixir_dockerfile=$(strip_dockerfile "$elixir_dockerfile")

	local ruby_dockerfile=$(fetch_contents "https://raw.githubusercontent.com/docker-library/ruby/master/${RUBY_BASE_VERSION}/jessie/Dockerfile")
	local cleaned_ruby_dockerfile=$(strip_dockerfile "$ruby_dockerfile")

	export ERLANG="${cleaned_erlang_dockerfile}"
	export ELIXIR="${cleaned_elixir_dockerfile}"
	export RUBY="${cleaned_ruby_dockerfile}"

	echo "Building Dockerfile"
	cat > ./Dockerfile <<EOF
FROM buildpack-deps:jessie

## ERLANG

${ERLANG}

## Elixir

${ELIXIR}

## Ruby

${RUBY}

## Customizations

RUN mix local.hex --force \\
    && mix local.rebar --force \\
    && runtimeDeps='ca-certificates' \\
    && apt-get update \\
    && apt-get install -y --no-install-recommends \$runtimeDeps \\
    && rm -rf /var/lib/apt/lists/*

CMD ["iex"]
EOF
}

main "$@"
