# Devcontainer for building the EXR wrapper with Emscripten
# Uses Ubuntu base and installs a modern upstream Emscripten SDK (3.x)

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

# Base build tools and utilities
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        curl \
        ca-certificates \
        xz-utils \
        pkg-config \
        ninja-build \
        python3 \
        python-is-python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install emscripten SDK
# Default to latest upstream SDK; override via devcontainer.json args if needed.
ARG EMSCRIPTEN_SDK_ID=latest
ENV EMSDK=/opt/emsdk
RUN git clone https://github.com/emscripten-core/emsdk.git "$EMSDK" \
    && cd "$EMSDK" \
    && git fetch --tags \
    && bash -lc 'set -euo pipefail; \
        REQ="${EMSCRIPTEN_SDK_ID}"; \
        echo "Requested EMSDK: ${REQ}"; \
        CANDIDATES=( \
          "sdk-${REQ}-64bit" \
          "${REQ}" \
        ); \
        TARGET=""; \
        for cand in "${CANDIDATES[@]}"; do \
          echo "Trying to install: $cand"; \
          if ./emsdk install "$cand"; then \
            TARGET="$cand"; \
            break; \
          else \
            echo "Candidate failed: $cand"; \
          fi; \
        done; \
        if [ -z "$TARGET" ]; then \
          echo "Failed to resolve a valid emsdk target for ${REQ}"; \
          echo "Available SDKs (including old):"; \
          ./emsdk list --old || true; \
          exit 1; \
        fi; \
        echo "Activating EMSDK target: ${TARGET}"; \
        ./emsdk activate "${TARGET}";'

# Make emscripten available for all shells
RUN echo 'source /opt/emsdk/emsdk_env.sh >/dev/null 2>&1 || true' > /etc/profile.d/emsdk.sh \
    && chmod +x /etc/profile.d/emsdk.sh

# Ensure the default non-root user also sources emsdk on login
RUN echo '\n# Emscripten env' >> /etc/skel/.bashrc \
    && echo 'source /opt/emsdk/emsdk_env.sh >/dev/null 2>&1 || true' >> /etc/skel/.bashrc

# Default workspace install prefix used by the Makefile (../install)
ENV WRAPPER_INSTALL=/workspaces/openexr-wrap-em/install

# Print versions to help debugging image builds
RUN bash -lc 'source /opt/emsdk/emsdk_env.sh && emcc -v && node --version && python --version && cmake --version'
