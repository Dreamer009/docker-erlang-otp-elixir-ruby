# docker-erlang-otp-elixir-ruby

This Dockerfile is published on the Docker Hub at [csd1/erlang-otp-elixir-ruby](https://hub.docker.com/r/csd1/erlang-otp-elixir-ruby/).

# Updating

The `build-dockerfile.sh` script updates the contents of the `Dockerfile` by pulling down the latest contents of the `erlang-otp`, `elixir`, and `ruby` dockerfiles and concatting them together.

This is a manual process and the updated `Dockerfile` will need to be checked in to this repository for docker hub to pickup the changes.
