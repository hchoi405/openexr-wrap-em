INCLUDE=../install/include
IMATH_INCLUDE=../install/include/Imath
LIBRARY=../install/lib
CXXFLAGS=-std=c++14 -O3
# OpenEXR 3.x + Imath 3.x static libs
LDFLAGS=-lOpenEXR-3_2 -lOpenEXRCore-3_2 -lIex-3_2 -lIlmThread-3_2 -lImath-3_1 -lz --llvm-lto 1

.PHONY=clean

# Emscripten cache directory (make sure it's writable)
EM_CACHE_DIR?=../.emscripten_cache
# Local Emscripten config file
EM_CONFIG_FILE?=../.emscripten

EMFLAGS=
EMFLAGS+=-s ALLOW_MEMORY_GROWTH=1
#EMFLAGS+=-s TOTAL_MEMORY=134217728
#EMFLAGS+=-s EXPORTED_FUNCTIONS='["_loadEXRRaw", "_loadEXRVec", "_loadEXRStr"]'
EMFLAGS+=-s NO_EXIT_RUNTIME=1
EMFLAGS+=-s NO_FILESYSTEM=1
EMFLAGS+=-s MODULARIZE=1
EMFLAGS+=-s EXPORT_NAME="EXR"
EMFLAGS+=-s USE_PTHREADS=0

# embind
EMFLAGS+=--bind -DWRAPPER_EMBIND

exr-wrap.js: exr-wrap.cpp
	mkdir -p $(EM_CACHE_DIR)
	# Ensure a local EM_CONFIG exists to avoid writing under /opt/emsdk
	@if [ ! -f $(EM_CONFIG_FILE) ]; then emcc --generate-config >/dev/null 2>&1 || true; fi
	EM_CONFIG=$(abspath $(EM_CONFIG_FILE)) EM_CACHE=$(abspath $(EM_CACHE_DIR)) EMCC_SKIP_SANITY_CHECK=1 EMCC_CORES=1 em++ $(EMFLAGS) $< -o $@ -I$(INCLUDE) -I$(IMATH_INCLUDE) -L$(LIBRARY) $(CXXFLAGS) $(LDFLAGS)

clean:
	rm -f exr-wrap.js exr-wrap.js.mem exr-wrap.wasm
