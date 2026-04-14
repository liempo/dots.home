FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
# Minimal deps + Node/npm for agent-browser install
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    ca-certificates curl git sudo ripgrep \
    nodejs npm \
 && rm -rf /var/lib/apt/lists/*
# Install agent-browser + bake Chrome + Linux deps into the image
RUN npm i -g agent-browser \
 && agent-browser install --with-deps