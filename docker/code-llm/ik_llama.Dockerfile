ARG CUDA_DEVEL_IMAGE=nvidia/cuda:12.8.1-devel-ubuntu24.04
ARG CUDA_RUNTIME_IMAGE=nvidia/cuda:12.8.1-runtime-ubuntu24.04
ARG UBUNTU_IMAGE=ubuntu:24.04

FROM ${CUDA_DEVEL_IMAGE} AS build-cuda
ARG IK_LLAMA_CPP_REPO=https://github.com/ikawrakow/ik_llama.cpp.git
ARG IK_LLAMA_CPP_REF=main
ARG IK_LLAMA_BUILD_JOBS=16
ARG IK_LLAMA_CUDA_ARCHITECTURES=120
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      cmake \
      g++ \
      git \
      libcurl4-openssl-dev \
      make \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src/ik_llama.cpp
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs
RUN ln -sf libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
RUN git init \
    && git remote add origin "${IK_LLAMA_CPP_REPO}" \
    && git fetch --depth 1 origin "${IK_LLAMA_CPP_REF}" \
    && git checkout --detach FETCH_HEAD
RUN cmake -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DGGML_CUDA=ON \
      -DGGML_NATIVE=OFF \
      -DCMAKE_CUDA_ARCHITECTURES="${IK_LLAMA_CUDA_ARCHITECTURES}" \
      -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -Wl,-rpath-link,/usr/local/cuda/lib64/stubs" \
    && cmake --build build --target llama-server -j"${IK_LLAMA_BUILD_JOBS}"

FROM ${CUDA_RUNTIME_IMAGE} AS cuda
ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/app
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      libcurl4 \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build-cuda /src/ik_llama.cpp/build/bin/llama-server /app/llama-server
COPY --from=build-cuda /src/ik_llama.cpp/build/src/libllama.so /app/libllama.so
COPY --from=build-cuda /src/ik_llama.cpp/build/ggml/src/libggml.so /app/libggml.so
COPY --from=build-cuda /src/ik_llama.cpp/build/examples/mtmd/libmtmd.so /app/libmtmd.so
ENTRYPOINT ["/app/llama-server"]

FROM ${UBUNTU_IMAGE} AS build-cpu
ARG IK_LLAMA_CPP_REPO=https://github.com/ikawrakow/ik_llama.cpp.git
ARG IK_LLAMA_CPP_REF=main
ARG IK_LLAMA_BUILD_JOBS=16
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      cmake \
      g++ \
      git \
      libcurl4-openssl-dev \
      make \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src/ik_llama.cpp
RUN git init \
    && git remote add origin "${IK_LLAMA_CPP_REPO}" \
    && git fetch --depth 1 origin "${IK_LLAMA_CPP_REF}" \
    && git checkout --detach FETCH_HEAD
RUN cmake -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DGGML_NATIVE=OFF \
    && cmake --build build --target llama-server -j"${IK_LLAMA_BUILD_JOBS}"

FROM ${UBUNTU_IMAGE} AS cpu
ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/app
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      libcurl4 \
      libgomp1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build-cpu /src/ik_llama.cpp/build/bin/llama-server /app/llama-server
COPY --from=build-cpu /src/ik_llama.cpp/build/src/libllama.so /app/libllama.so
COPY --from=build-cpu /src/ik_llama.cpp/build/ggml/src/libggml.so /app/libggml.so
COPY --from=build-cpu /src/ik_llama.cpp/build/examples/mtmd/libmtmd.so /app/libmtmd.so
ENTRYPOINT ["/app/llama-server"]
