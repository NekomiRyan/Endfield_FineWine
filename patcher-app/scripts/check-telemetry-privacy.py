#!/usr/bin/env python3
"""Build-time privacy guard for the patcher's per-run usage statistics.

This is a static, source-level audit. It complements the UsageTelemetryTests and
checks the product guarantees that are easy to accidentally regress:

* nothing is sent automatically;
* the only send action is the user's explicit choice in the post-patch dialog;
* the dialog shows the exact payload before sending;
* only completed patch runs and allowlisted fields can be reported.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
TELEMETRY = APP / "Sources/FineWinePatcher/UsageTelemetry.swift"
ENGINE = APP / "Sources/FineWinePatcher/PatcherEngine.swift"
CONTENT = APP / "Sources/FineWinePatcher/ContentView.swift"
PROMPT = APP / "Sources/FineWinePatcher/PatchTelemetryPromptView.swift"
THANKYOU = APP / "Sources/FineWinePatcher/TelemetryThankYouView.swift"
README = APP / "README.md"
SOURCES = APP / "Sources/FineWinePatcher"

failures: list[str] = []


def check(condition: bool, description: str) -> None:
    if condition:
        print(f"  PASS  {description}")
    else:
        print(f"  FAIL  {description}", file=sys.stderr)
        failures.append(description)


def block(text: str, start: str, end: str) -> str:
    match = re.search(re.escape(start) + r"(.*?)" + re.escape(end), text, re.S)
    return match.group(1) if match else ""


def swift_strings(value: str) -> set[str]:
    return set(re.findall(r'"([^"]+)"', value))


telemetry = TELEMETRY.read_text(encoding="utf-8")
engine = ENGINE.read_text(encoding="utf-8")
content = CONTENT.read_text(encoding="utf-8")
prompt = PROMPT.read_text(encoding="utf-8")
thanks = THANKYOU.read_text(encoding="utf-8")
readme = README.read_text(encoding="utf-8")
all_sources = "\n".join(p.read_text(encoding="utf-8") for p in SOURCES.glob("*.swift"))

print("Telemetry privacy audit")

# 1. No persistent toggle and no automatic launch/event recording.
check("finewine.statistics.enabled" not in all_sources, "there is no persistent telemetry toggle")
check("recordAppLaunch" not in all_sources, "there is no automatic app-launch reporting")
check("UsageTelemetry.record(" not in all_sources, "there are no automatic telemetry event calls")
check(
    "Toggle(\"Share anonymous usage statistics" not in content,
    "the main page has no telemetry checkbox",
)

# 2. A prompt is created for both outcomes of a patch run, and only then.
check(
    "makePatchPrompt(\n                    succeeded: true" in engine,
    "successful patch runs create a send prompt",
)
check(
    "makePatchPrompt(\n                    succeeded: false" in engine,
    "failed patch runs create a send prompt",
)
check(engine.count("self.telemetryPrompt = prompt") == 2, "both patch outcomes set the prompt")
check(
    "telemetryPrompt = nil" in block(engine, "func reset() {", "\n    }"),
    "starting a new patch clears any stale prompt",
)

# 3. The only network send is the user's explicit choice in the prompt.
send_calls = re.findall(r"UsageTelemetry\.send\(([^)]*)\)", all_sources)
check(send_calls == ["prompt"], "the only send call is the user's Send Statistics action")
check("onSend: { UsageTelemetry.send(prompt) }" in content, "Send Statistics is wired to the dialog choice")
check("UsageTelemetry.send" not in prompt, "the prompt view itself cannot send before a choice")
check("UsageTelemetry.send" not in engine, "the patch engine never sends automatically")

# 4. Endpoint and event/metadata allowlists.
check(
    'URL(string: "https://endfield-fine-wine.lovable.app/api/statistics")!' in telemetry,
    "statistics endpoint uses HTTPS",
)
events_block = re.search(r"allowedEvents: Set<String> = \[(.*?)\]", telemetry, re.S).group(1)
allowed_events = swift_strings(events_block)
check(allowed_events == {"patch_succeeded", "patch_failed"}, "only completed patch outcomes are allowed")
metadata_block = re.search(
    r"allowedMetadataKeys: Set<String> = \[(.*?)\]", telemetry, re.S
).group(1)
allowed_metadata = swift_strings(metadata_block)
check(
    allowed_metadata == {"gptk", "duration_seconds", "failed_step"},
    "telemetry metadata allowlist is exact",
)
check(
    "metadata.filter { allowedMetadataKeys.contains($0.key) }" in telemetry,
    "unknown metadata keys are dropped before sending",
)
check(
    "guard allowedEvents.contains(prompt.event) else { return }" in telemetry,
    "unknown event names are rejected before sending",
)

# 5. The event schema must stay deliberately small.
event_struct = block(telemetry, "private struct Event: Encodable {", "\n    }")
event_fields = set(re.findall(r"let\s+([A-Za-z_][A-Za-z0-9_]*)", event_struct))
check(
    event_fields == {"app", "event", "count", "appVersion", "osMajor", "metadata"},
    "event payload contains only the approved fields",
)
forbidden_terms = {
    "path", "file", "bottle", "user", "username", "email", "host", "hostname",
    "serial", "machine", "token", "password", "secret", "cookie", "ip",
}
check(
    not any(term in event_struct.lower() for term in forbidden_terms),
    "event payload contains no path/account/machine identifier fields",
)

# 6. The dialog must explain the ask, show the exact payload, and default to not sending.
check("Send anonymous statistics for this" in prompt, "dialog title asks about this patch run")
check("This report is optional" in prompt, "dialog explains that the report is optional")
check("Nothing has been sent yet" in prompt, "dialog states nothing was sent automatically")
check("prioritise compatibility and performance fixes" in prompt, "dialog explains how the data helps")
check("Preview — exactly what would be sent" in prompt, "dialog shows the exact payload before sending")
check("prompt.json" in prompt, "dialog preview uses the same payload encoder")
check('Button("Don\'t Send")' in prompt and 'Button("Send Statistics")' in prompt,
      "dialog offers explicit Send and Don't Send choices")
check("No file paths" in prompt, "dialog lists what is never sent")
check("source IP" in prompt or "your IP address" in prompt, "dialog discloses ordinary network metadata")

# 7. Sending must lead to a thank-you celebration rather than closing immediately.
check("if sent {" in prompt and "TelemetryThankYouView" in prompt,
      "Send Statistics transitions to the thank-you view")
check("NSPasteboard" not in thanks and "UsageTelemetry.send" not in thanks,
      "thank-you view cannot send data")
check("Thank you!" in thanks, "thank-you dialog thanks the contributor")
check("sincerely appreciate" in thanks, "thank-you dialog expresses appreciation")
check("CelebrationConfetti" in thanks, "thank-you dialog includes confetti")
check("ConfettiPiece.makePieces()" in thanks and ".animation(" in thanks,
      "confetti celebration is animated")

# 8. The user-facing copy and README must describe the per-run prompt.
check("never sent automatically" in content, "footer says statistics are never sent automatically")
check("after each patch run" in content.lower(), "footer says the prompt follows each patch run")
check("## Per-run anonymous usage statistics" in readme, "README has a per-run privacy section")
check("**Why this helps.**" in readme, "README explains how the data improves compatibility")
check("**What is collected.**" in readme, "README documents the collected fields")
check("**What is never sent.**" in readme, "README documents what is never sent")
check("Preview — exactly what would be sent" in readme, "README explains the in-dialog preview")
check("thank-you dialog" in readme.lower(), "README documents the thank-you celebration")
check("nothing is sent automatically" in readme.lower(), "README says nothing is sent automatically")
check("source IP address" in readme, "README discloses ordinary network metadata")

if failures:
    print(f"\nPrivacy audit failed with {len(failures)} error(s).", file=sys.stderr)
    sys.exit(1)

print("\nPrivacy audit passed: statistics are per-run, previewed, and user-confirmed.")
