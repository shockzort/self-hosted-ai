ARG CUDA_IMAGE=nvidia/cuda:13.0.2-cudnn-devel-ubuntu24.04
FROM ${CUDA_IMAGE}

ARG COMFYUI_REF=master
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PYTHONUNBUFFERED=1
ENV PATH=/opt/venv/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        gosu \
        libgl1 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv \
    && python -m pip install --upgrade pip setuptools wheel

WORKDIR /opt

RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI.git ComfyUI \
    && cd /opt/ComfyUI \
    && if [ "${COMFYUI_REF}" != "master" ]; then \
        git fetch --depth 1 origin "${COMFYUI_REF}" && git checkout FETCH_HEAD; \
    fi \
    && git rev-parse HEAD > /opt/ComfyUI/.image-build-ref \
    && python -m pip install torch torchvision torchaudio --index-url "${TORCH_INDEX_URL}" \
    && python -m pip install -r requirements.txt \
    && python -m pip install "huggingface_hub[cli,hf_transfer]" \
    && python -m pip install sageattention \
    && if [ -f manager_requirements.txt ]; then python -m pip install -r manager_requirements.txt; fi

RUN chown -R 1000:1000 /opt/ComfyUI /opt/venv

COPY docker/comfyui/entrypoint.sh /usr/local/bin/comfyui-entrypoint
RUN chmod +x /usr/local/bin/comfyui-entrypoint

WORKDIR /opt/ComfyUI
EXPOSE 8188

ENTRYPOINT ["comfyui-entrypoint"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188", "--enable-manager"]
