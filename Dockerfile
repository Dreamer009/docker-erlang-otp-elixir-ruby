FROM golang:1.9-alpine as build

RUN apk add -U bash git make
RUN go get github.com/Shopify/ejson \
    && (cd /go/src/github.com/Shopify/ejson; make binaries)

# Release Image
FROM debian:stretch

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH "$GEM_HOME"
ENV RUBY_MAJOR=2.5 \
    RUBY_VERSION=2.5.1 \
    RUBY_DOWNLOAD_SHA256=886ac5eed41e3b5fc699be837b0087a6a5a3d10f464087560d2d21b3e71b754d \
    RUBYGEMS_VERSION=2.7.7 \
    BUNDLER_VERSION=1.16.3 \
# install things globally, for great justice
# and don't create ".bundle" in all our apps
    GEM_HOME=/usr/local/bundle \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME" \
# path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
    PATH=$GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH \
    OTP_VERSION=21.1 \
    OTP_DOWNLOAD_SHA256=7212f895ae317fa7a086fa2946070de5b910df5d41263e357d44b0f1f410af0f \
# elixir expects utf8.
    ELIXIR_VERSION=v1.7.3 \
    ELIXIR_DOWNLOAD_SHA256=2ea1eef6751c54b475225f20caaad20702c198fbddff1cb1513b03aee25a5f90 \
    LANG=C.UTF-8

RUN set -ex \
	\
        && runtimeDeps='libpq5 ca-certificates jq imagemagick' \
        && rubyRuntimeDeps=' \
		bzip2 \
		ca-certificates \
		libffi-dev \
		libgdbm3 \
		libssl-dev \
		libyaml-dev \
		procps \
		zlib1g-dev \
        ' \
# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
	&& rubyBuildDeps=' \
		autoconf \
		bison \
		dpkg-dev \
		gcc \
		libbz2-dev \
		libgdbm-dev \
		libglib2.0-dev \
		libncurses-dev \
		libreadline-dev \
		libxml2-dev \
		libxslt-dev \
		make \
		ruby \
		wget \
		xz-utils \
	' \
	&& erlangRuntimeDeps=' \
		libodbc1 \
		libssl1.1 \
		libsctp1 \
	' \
	&& erlangBuildDeps=' \
		autoconf \
		dpkg-dev \
		gcc \
		g++ \
		make \
		libncurses-dev \
		unixodbc-dev \
		libssl-dev \
		libsctp-dev \
	' \
	&& erlangFetchDeps=' \
		curl \
		ca-certificates' \
	&& elixirBuildDeps=' \
		ca-certificates \
		curl \
		unzip \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $erlangFetchDeps \
	&& apt-get install -y --no-install-recommends $runtimeDeps $rubyRuntimeDeps $erlangRuntimeDeps \
	&& apt-get install -y --no-install-recommends $rubyBuildDeps $erlangBuildDeps $elixirBuildDeps \
##########
# Ruby
# https://github.com/docker-library/ruby/blob/eca972d167cf4291de898e85aaf50d9a1929d4c7/2.5/stretch/slim/Dockerfile
##########
# skip installing gem documentation
      && mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc \
	\
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& dpkg-query --show --showformat '${package}\n' \
		| grep -P '^libreadline\d+$' \
		| xargs apt-mark manual \
	&& cd / \
	&& rm -r /usr/src/ruby \
	\
	&& gem update --system "$RUBYGEMS_VERSION" \
	&& gem install bundler --version "$BUNDLER_VERSION" --force \
	&& rm -r /root/.gem/ \
# adjust permissions of a few directories for running "gem install" as an arbitrary user
        && mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME" \
# (BUNDLE_PATH = GEM_HOME, no need to mkdir/chown both)
##########
# Erlang
# https://github.com/erlang/docker-erlang-otp/blob/fe505cb6aa9afc509add31825b7f1734a0163c04/21/slim/Dockerfile
##########
	&& OTP_DOWNLOAD_URL="https://github.com/erlang/otp/archive/OTP-${OTP_VERSION}.tar.gz" \
	&& curl -fSL -o otp-src.tar.gz "$OTP_DOWNLOAD_URL" \
	&& echo "$OTP_DOWNLOAD_SHA256  otp-src.tar.gz" | sha256sum -c - \
	&& export ERL_TOP="/usr/src/otp_src_${OTP_VERSION%%@*}" \
	&& mkdir -vp $ERL_TOP \
	&& tar -xzf otp-src.tar.gz -C $ERL_TOP --strip-components=1 \
	&& rm otp-src.tar.gz \
	&& ( cd $ERL_TOP \
	  && ./otp_build autoconf \
	  && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	  && ./configure --build="$gnuArch" \
	  && make -j$(nproc) \
	  && make install ) \
	&& find /usr/local -name examples | xargs rm -rf \
##########
# Elixir
# https://github.com/c0b/docker-elixir/blob/a502dfaf78efdf61ec82419c190741df293c0b29/1.7/slim/Dockerfile
##########
        && ELIXIR_DOWNLOAD_URL="https://repo.hex.pm/builds/elixir/$ELIXIR_VERSION-otp-$(echo $OTP_VERSION | cut -d. -f1).zip" \
	&& curl -fSL -o elixir-precompiled.zip $ELIXIR_DOWNLOAD_URL \
	&& echo "$ELIXIR_DOWNLOAD_SHA256  elixir-precompiled.zip" | sha256sum -c - \
	&& unzip -d /usr/local elixir-precompiled.zip \
	&& rm elixir-precompiled.zip \
##########
# Cleanup
##########
	&& apt-get purge -y --auto-remove $rubyBuildDeps $erlangBuildDeps $erlangFetchDeps $elixirBuildDeps \
        ## Reinstall runtime deps in case removing build deps removed an important runtime dep
	&& apt-get install -y --no-install-recommends $runtimeDeps $rubyRuntimeDeps $erlangRuntimeDeps \
	&& rm -rf /var/lib/apt/lists/*

##########
##########
##########



# Customizations

COPY --from=build /go/src/github.com/Shopify/ejson/build/bin/linux-amd64 /usr/local/bin/ejson

RUN mix local.hex --force \
    && mix local.rebar --force

CMD ["iex"]
