#!/usr/bin/env python3
"""CI wrapper that runs git-wiki-builder with two runtime patches.

git-wiki-builder 0.1.4 has two gaps that matter for this repo:

1. The `wiki_structure` key documented for `.git-wiki-builder.yml` is never
   read — `Config.wiki_structure` is a hardcoded default (8 sections, including
   an "API Reference" section that would make the AI invent fake API docs for
   a Wine-patch repo). We replace the property with our structure from the
   config file.

2. Free OpenRouter models intermittently answer HTTP 200 with a JSON error
   body (rate limit / upstream saturation) instead of a completion. The stock
   client then dies with "'NoneType' object is not subscriptable" on
   `response.choices[0]`. We swap the generation call for one that detects
   that shape, logs the API's error payload (so failures are diagnosable from
   the Actions log), and retries with backoff.

Run instead of the `git-wiki-builder` console script; all CLI flags pass
through unchanged (e.g. `--dry-run`, `--verbose`, `--output-dir`).
"""

import logging
import time
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = REPO_ROOT / ".git-wiki-builder.yml"

# Same system prompt the stock client uses.
SYSTEM_PROMPT = (
    "You are a technical documentation expert. Generate high-quality, "
    "well-structured markdown documentation that follows best practices. "
    "Ensure proper heading hierarchy, clear formatting, and comprehensive "
    "coverage of the requested topic."
)

ATTEMPTS = 3
BACKOFF_SECONDS = (5, 15, 30)


def patch_wiki_structure() -> None:
    """Make Config.wiki_structure return our .git-wiki-builder.yml structure.

    The generator also unconditionally extends `structure["API Reference"]`
    (and "Deployment"/"Development") when it detects API/Docker/test/CI markers
    in the repo — a KeyError for any custom structure that drops those
    sections — so its structure builder is replaced with a safe version too.
    """
    from git_wiki_builder.config import Config
    from git_wiki_builder.generator import WikiGenerator

    custom = {}
    if CONFIG_PATH.exists():
        custom = yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8")) or {}

    structure = custom.get("wiki_structure")
    if not structure:
        print("[generate-wiki] no wiki_structure in config; using tool default")
        return

    Config.wiki_structure = property(lambda self: structure)

    def safe_structure(self, project_analysis):
        structure = {k: list(v) for k, v in dict(self.config.wiki_structure).items()}
        if project_analysis.has_api_docs and "API Reference" in structure:
            structure["API Reference"].extend(["sdk_reference", "code_examples"])
        if project_analysis.has_docker and "Deployment" in structure:
            structure["Deployment"].extend(["docker_deployment", "container_management"])
        if project_analysis.has_tests and "Development" in structure:
            structure["Development"].extend(["running_tests", "test_coverage"])
        if project_analysis.has_ci_cd and "Development" in structure:
            structure["Development"].extend(["ci_cd_pipeline", "automated_deployment"])
        return {k: v for k, v in structure.items() if v}

    WikiGenerator._generate_wiki_structure = safe_structure

    pages = sum(len(v) for v in structure.values())
    print(
        f"[generate-wiki] patched wiki_structure: "
        f"{len(structure)} sections / {pages} pages"
    )


def patch_ai_client() -> None:
    """Retry AI calls and surface HTTP-200-with-error-body responses."""
    from git_wiki_builder.ai_client import AIClient

    log = logging.getLogger("generate-wiki")

    def generate_with_retry(self, prompt: str) -> str:
        last_error: Exception = RuntimeError("unreachable")
        for attempt in range(1, ATTEMPTS + 1):
            try:
                response = self.client.chat.completions.create(
                    model=self.config.ai_model,
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": prompt},
                    ],
                    temperature=0.3,
                    max_tokens=4000,
                )
                # OpenRouter free models can answer 200 with {"error": {...}}
                # and no `choices`; the stock code crashes on choices[0].
                choices = getattr(response, "choices", None)
                if not choices:
                    body = (
                        response.model_dump_json()
                        if hasattr(response, "model_dump_json")
                        else repr(response)
                    )
                    raise RuntimeError(
                        "API returned a non-completion response "
                        f"(HTTP 200 with error body): {body[:2000]}"
                    )
                content = choices[0].message.content
                if not content:
                    raise RuntimeError(
                        "completion had empty content "
                        "(reasoning-only output or truncated response)"
                    )
                return str(content).strip()
            except Exception as error:  # free models fail in many ways; retry all
                last_error = error
                if attempt < ATTEMPTS:
                    wait = BACKOFF_SECONDS[attempt - 1]
                    log.warning(
                        "AI request failed (attempt %d/%d), retrying in %ds: %s",
                        attempt,
                        ATTEMPTS,
                        wait,
                        str(error)[:500],
                    )
                    time.sleep(wait)
        raise last_error

    AIClient._generate_openai_content = generate_with_retry


def main() -> None:
    patch_wiki_structure()
    patch_ai_client()

    from git_wiki_builder.cli import main as cli_main

    cli_main()  # click consumes sys.argv[1:], so flags pass through


if __name__ == "__main__":
    main()