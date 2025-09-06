#!/usr/bin/env bash
set -euo pipefail

# This script builds zlib (latest default), Imath 3.x, and OpenEXR 3.x
# using emscripten as described in README.md. It installs into
# $WRAPPER_INSTALL (defaults to ../install from the wrap/ folder).

if ! command -v emcc >/dev/null 2>&1; then
  echo "emcc not found. Ensure emscripten SDK is activated (source /opt/emsdk/emsdk_env.sh)." >&2
  exit 1
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
WRAPPER_INSTALL_DEFAULT="$REPO_ROOT/install"
WRAPPER_INSTALL="${WRAPPER_INSTALL:-$WRAPPER_INSTALL_DEFAULT}"

# Use a writable Emscripten cache to avoid permission errors under /opt/emsdk
EM_CACHE_DEFAULT="$REPO_ROOT/.emscripten_cache"
export EM_CACHE="${EM_CACHE:-$EM_CACHE_DEFAULT}"
mkdir -p "$EM_CACHE" || true
# If EM_CACHE is not writable (e.g., points under /opt), override to local default
if ! (touch "$EM_CACHE/.write_test" >/dev/null 2>&1 && rm -f "$EM_CACHE/.write_test" >/dev/null 2>&1); then
  echo "EM_CACHE at $EM_CACHE is not writable; switching to $EM_CACHE_DEFAULT"
  export EM_CACHE="$EM_CACHE_DEFAULT"
  mkdir -p "$EM_CACHE"
fi
echo "Using EM_CACHE=$EM_CACHE"

# Force a local, writable Emscripten config that points to our cache
LOCAL_EM_CONFIG="$REPO_ROOT/.emscripten"
export EM_CONFIG="$LOCAL_EM_CONFIG"
if [ ! -f "$LOCAL_EM_CONFIG" ]; then
  echo "Generating local Emscripten config at $LOCAL_EM_CONFIG"
  emcc --generate-config >/dev/null 2>&1 || true
fi
# Update cache path in config (support both EM_CACHE and CACHE keys)
if [ -f "$LOCAL_EM_CONFIG" ]; then
  sed -i -E "s|^(EM_CACHE\s*=).*$|\1 '$EM_CACHE'|; s|^(CACHE\s*=).*$|\1 '$EM_CACHE'|" "$LOCAL_EM_CONFIG" || true
fi

# Ensure core tool paths are set (avoid empty BINARYEN_ROOT error)
EMSDK_ROOT="${EMSDK:-/opt/emsdk}"
EMSCRIPTEN_ROOT_DEFAULT="$EMSDK_ROOT/upstream/emscripten"
LLVM_ROOT_DEFAULT="$EMSDK_ROOT/upstream/bin"
BINARYEN_ROOT_DEFAULT="$EMSDK_ROOT/upstream"
NODE_BIN_DEFAULT="$(command -v node || true)"

ensure_cfg_key() {
  local key="$1"; shift
  local val="$1"; shift || true
  if grep -q "^${key}\s*=" "$LOCAL_EM_CONFIG"; then
    sed -i -E "s|^(${key}\s*=).*$|\1 '$val'|" "$LOCAL_EM_CONFIG"
  else
    echo "${key} = '${val}'" >> "$LOCAL_EM_CONFIG"
  fi
}

ensure_cfg_key EMSCRIPTEN_ROOT "$EMSCRIPTEN_ROOT_DEFAULT"
ensure_cfg_key LLVM_ROOT "$LLVM_ROOT_DEFAULT"
ensure_cfg_key BINARYEN_ROOT "$BINARYEN_ROOT_DEFAULT"
if [ -n "$NODE_BIN_DEFAULT" ]; then
  ensure_cfg_key NODE_JS "$NODE_BIN_DEFAULT"
fi

echo "Using WRAPPER_INSTALL=$WRAPPER_INSTALL"
mkdir -p "$WRAPPER_INSTALL"

WORKDIR=$(mktemp -d)
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT
cd "$WORKDIR"

NPROC=$(nproc || echo 2)

echo "Fetching sources (git)..."

# ---- zlib (use latest stable by default) ----
# Allow override via ZLIB_VERSION env. Defaults to 1.3.1.
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
ZLIB_DIR="zlib-src"
if ! git clone --depth 1 --branch "v${ZLIB_VERSION}" https://github.com/madler/zlib.git "$ZLIB_DIR"; then
  echo "ERROR: Unable to clone zlib v${ZLIB_VERSION}." >&2
  exit 1
fi

# ---- Imath (3.x default) ----
IMATH_VERSION="${IMATH_VERSION:-3.1.11}"
IMATH_DIR="imath-src"
if ! git clone --depth 1 --branch "v${IMATH_VERSION}" https://github.com/AcademySoftwareFoundation/Imath.git "$IMATH_DIR"; then
  echo "ERROR: Unable to clone Imath v${IMATH_VERSION}." >&2
  exit 1
fi

# ---- OpenEXR (3.x default) ----
OPENEXR_VERSION="${OPENEXR_VERSION:-3.2.4}"
OPENEXR_DIR="openexr-src"
if ! git clone --depth 1 --branch "v${OPENEXR_VERSION}" https://github.com/AcademySoftwareFoundation/openexr.git "$OPENEXR_DIR"; then
  echo "ERROR: Unable to clone OpenEXR v${OPENEXR_VERSION}." >&2
  exit 1
fi

# Build zlib
echo "Building zlib ${ZLIB_VERSION}..."
pushd "$ZLIB_DIR" >/dev/null
emconfigure ./configure --static --prefix "$WRAPPER_INSTALL"
# Adjust AR and flags as per README
sed -i 's/^AR=.*/AR=emar/; s/^ARFLAGS=.*/ARFLAGS=r/' Makefile
if ! grep -q "^-O3" Makefile; then
  sed -i 's/^CFLAGS = \(.*\)$/CFLAGS = \1 -O3/' Makefile
fi
emmake make -j"$NPROC"
emmake make install
popd >/dev/null

# Build Imath
echo "Building Imath ${IMATH_VERSION}..."
pushd "$IMATH_DIR" >/dev/null
mkdir -p build && cd build
emcmake cmake .. \
  -DCMAKE_INSTALL_PREFIX="$WRAPPER_INSTALL" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_Threads=ON \
  -DCMAKE_C_STANDARD=11 \
  -DCMAKE_CXX_STANDARD=14 \
  -DCMAKE_C_FLAGS="-s USE_PTHREADS=0" \
  -DCMAKE_CXX_FLAGS="-s USE_PTHREADS=0" \
  -DCMAKE_EXE_LINKER_FLAGS="-s USE_PTHREADS=0"
emmake make -j"$NPROC"
emmake make install
popd >/dev/null

# Build OpenEXR
echo "Building OpenEXR ${OPENEXR_VERSION}..."
pushd "$OPENEXR_DIR" >/dev/null
mkdir -p build && cd build
emcmake cmake .. \
  -DCMAKE_INSTALL_PREFIX="$WRAPPER_INSTALL" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DOPENEXR_BUILD_TOOLS=OFF \
  -DOPENEXR_BUILD_TESTS=OFF \
  -DOPENEXR_BUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DOPENEXR_ENABLE_THREADING=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_Threads=ON \
  -DCMAKE_PREFIX_PATH="$WRAPPER_INSTALL" \
  -DImath_DIR="$WRAPPER_INSTALL/lib/cmake/Imath" \
  -DZLIB_INCLUDE_DIR="$WRAPPER_INSTALL/include" \
  -DZLIB_LIBRARY="$WRAPPER_INSTALL/lib/libz.a" \
  -DCMAKE_C_STANDARD=11 \
  -DCMAKE_CXX_STANDARD=14 \
  -DCMAKE_C_FLAGS="-s USE_PTHREADS=0" \
  -DCMAKE_CXX_FLAGS="-s USE_PTHREADS=0" \
  -DCMAKE_EXE_LINKER_FLAGS="-s USE_PTHREADS=0"
emmake make -j"$NPROC"
emmake make install
popd >/dev/null

echo "\nAll dependencies built and installed to: $WRAPPER_INSTALL"
echo "Now build the wrapper:"
echo "  cd \"$REPO_ROOT/wrap\" && make"
