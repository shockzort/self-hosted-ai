# Cline / Roo Code

Use the OpenAI-compatible provider settings:

| Field | Value |
| --- | --- |
| Provider | `OpenAI Compatible` |
| Base URL | `http://127.0.0.1:8080/v1` |
| API key | `local-code-llm` |
| Model ID | `code/gemma4-fast` |
| Context window | `32768` |

Switch the model ID after changing profiles with `./scripts/code-llm.sh start <profile>`. For GLM 5+ use `code/glm51-1.7bpw` after starting `glm5-extreme`.
