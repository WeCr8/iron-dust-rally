from __future__ import annotations

import json
import urllib.error
import urllib.request


class LocalLLMError(RuntimeError):
    pass


def _post(url: str, payload: dict, timeout: int, api_key: str | None = None) -> dict:
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise LocalLLMError(f"Local model request failed: {exc}") from exc


def chat(runtime: str, base_url: str, model: str, messages: list[dict], timeout: int = 300, api_key: str | None = None, response_schema: dict | None = None) -> str:
    base = base_url.rstrip("/")
    if runtime == "ollama":
        data = _post(f"{base}/api/chat", {"model": model, "messages": messages, "stream": False, "format": response_schema or "json"}, timeout)
        try:
            return data["message"]["content"]
        except (KeyError, TypeError) as exc:
            raise LocalLLMError("Unexpected Ollama response") from exc
    if runtime in {"lmstudio", "llamacpp"}:
        data = _post(f"{base}/chat/completions", {"model": model, "messages": messages, "temperature": 0.15, "stream": False}, timeout)
        try:
            return data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LocalLLMError("Unexpected OpenAI-compatible response") from exc
    if runtime == "openrouter":
        if not api_key:
            raise LocalLLMError("OPENROUTER_API_KEY is required for the openrouter runtime")
        data = _post(
            f"{base}/chat/completions",
            {"model": model, "messages": messages, "temperature": 0.15, "stream": False, "response_format": {"type": "json_object"}},
            timeout,
            api_key,
        )
        try:
            return data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise LocalLLMError(f"Unexpected OpenRouter response: {data}") from exc
    raise LocalLLMError(f"Unsupported runtime: {runtime}")
