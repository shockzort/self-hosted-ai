# Self-hosted image/video/audio generation

This task requires tooling, scripts, environments, and instructions for repeatable and reliable preparation and deployment of a self-hosted inference system for current neural network models.

## Product requirements

For the operator:

- As the system operator, I must be able to prepare, deploy, and run the inference system in a controlled and isolated environment.
- As the system operator, I must be able to maintain, update, and extend supported models and algorithms conveniently.
- As the system operator, I must be able to monitor and limit inference system resource usage (CPU/GPU).

For the user:

- As a user, I want convenient and visually clear access to system tools: prompt input and result browsing.
- As a user, I want to browse generation history separately for each algorithm.
- As a user, I want to interact with the system from another machine or phone on the local network.

## Functional requirements

- The system must use ComfyUI, or an equivalent interface if it is better, more convenient, and more broadly supported.
- The system must run in Docker or, at minimum, from an isolated virtual environment through UV.
- The system must run on a Linux machine with RTX 5090 GPU and 128 GB RAM. Future scope: CPU and 64 GB RAM on another installation with different algorithms.
- The system must include algorithms for:
  - Text-to-image generation with multiple neural networks.
  - Text-to-video generation with multiple neural networks.
  - Style transfer: photo_1 or video_1 as input, photo_2 or video_2 as input, face transfer from photo_1 to photo_2/video_2, or style/motion transfer from video_1 to video_2.
  - LLMs such as Gemma/Qwen/DeepSeek and other current models.
  - Other neural networks applicable to and compatible with the UI.

## Additional requirements and expected result

- Research the current state, approaches, and algorithms. Find manuals and recommended deployment recipes for similar systems.
- Build the system according to the requirements above and deploy it on the current machine.
- Clarify requirements with the user when needed.
- Record research results, preparation scripts, deployment scripts, and system instructions.
- Start the system and verify that it works.
