#!/usr/bin/env python3
"""Build-time privacy guard for the patcher's opt-in usage telemetry.

This is a static, source-level audit. It complements (and does not replace) the
UsageTelemetryTests. Keep it simple enough that a failed CI job points directly at
the guarantee that was broken.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
TELEMETRY = APP / "Sources/FineWinePatcher/UsageTelemetry.swift"
CONTENT = APP / "Sources/FineWinePatcher/ContentView.swift"
PREVIEW = APP / "Sources/FineWinePatcher/TelemetryPreviewView.swift"
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
content = CONTENT.read_text(encoding="utf-8")
readme = README.read_text(encoding="utf-8")

print("Telemetry privacy audit")

# 1. Opt-in is the product decision, not a default that can drift back to opt-out.
is_enabled = block(telemetry, "static var isEnabled: Bool {", "\n    }")
check("?? false" in is_enabled, "runtime telemetry default is disabled")
check("?? true" not in is_enabled, "runtime telemetry cannot default to enabled")
check(
    '@AppStorage("finewine.statistics.enabled") private var statisticsEnabled = false'
    in content,
    "footer toggle starts disabled",
)

# 2. No install/launch event may be recorded before consent.
launch = block(telemetry, "static func recordAppLaunch() {", "\n    }")
check(
    "guard isEnabled else { return }" in launch
    and launch.index("guard isEnabled") < launch.index("installedKey"),
    "launch/install recording waits for explicit consent",
)

# 3. The endpoint must remain HTTPS.
check(
    'URL(string: "https://endfield-fine-wine.lovable.app/api/statistics")!' in telemetry,
    "statistics endpoint uses HTTPS",
)

# 4. The event schema must stay deliberately small.
event_struct = block(telemetry, "private struct Event: Encodable {", "\n    }")
event_fields = set(re.findall(r"let\s+([A-Za-z_][A-Za-z0-9_]*)", event_struct))
expected_event_fields = {"app", "event", "count", "appVersion", "osMajor", "metadata"}
check(event_fields == expected_event_fields, "event payload contains only the approved fields")

forbidden_terms = {
    "path", "file", "bottle", "user", "username", "email", "host", "hostname",
    "serial", "machine", "token", "password", "secret", "cookie", "ip",
}
lower_schema = event_struct.lower()
check(
    not any(term in lower_schema for term in forbidden_terms),
    "event payload contains no path/account/machine identifier fields",
)

# 5. Metadata is an allowlist and every emitted key is on it.
metadata_block = block(
    telemetry, "static let allowedMetadataKeys: Set<String> = [", "\n    ]"
)
allowed_metadata = swift_strings(metadata_block)
expected_metadata = {"backend", "gptk", "duration_seconds", "failed_step"}
check(allowed_metadata == expected_metadata, "telemetry metadata allowlist is exact")
check(
    "metadata.filter { allowedMetadataKeys.contains($0.key) }" in telemetry,
    "unknown metadata keys are dropped before sending",
)

emitted_metadata: set[str] = set()
for swift_file in SOURCES.glob("*.swift"):
    source = swift_file.read_text(encoding="utf-8")
    if "UsageTelemetry.record" not in source:
        continue
    # Telemetry call sites build their metadata dictionaries locally; collect every
    # string-keyed entry from those files and require it to be on the allowlist.
    emitted_metadata |= set(re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)":', source))
check(
    emitted_metadata <= allowed_metadata,
    "all metadata emitted by call sites is allowlisted",
)

# 6. Event names are allowlisted, and every call site uses an approved name.
events_block = block(telemetry, "private static let allowedEvents: Set<String> = [", "\n    ]")
allowed_events = swift_strings(events_block)
check(
    "guard isEnabled, allowedEvents.contains(event) else { return }" in telemetry,
    "unknown event names are rejected before sending",
)
call_site_events: set[str] = set()
for swift_file in SOURCES.glob("*.swift"):
    source = swift_file.read_text(encoding="utf-8")
    call_site_events |= set(re.findall(r'UsageTelemetry\.record\("([^"]+)"', source))
check(
    call_site_events <= allowed_events | {"app_installed", "app_launched"},
    "all telemetry call sites use an allowlisted event",
)

# 7. The user can inspect the payload before anything is sent, whether opted in or not.
preview = PREVIEW.read_text(encoding="utf-8")
check("Preview data…" in content, "footer offers a data preview")
check(
    "before or after opting in" in content,
    "in-app copy says the preview remains available after opting in",
)
check(
    ".sheet(isPresented: $showTelemetryPreview) { TelemetryPreviewView() }" in content,
    "footer preview opens the telemetry preview sheet",
)
check("Preview only" in preview and "does not send" in preview,
      "preview is clearly labelled as non-sending")
check("sends no data" in preview, "preview repeats that it is local-only")
preview_block = block(telemetry, "static func previewSamples()", "\n    }")
preview_keys = set(re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)":', preview_block))
check(preview_keys <= allowed_metadata, "preview examples use only allowlisted metadata keys")
check(
    "send(" not in preview_block and "URLSession" not in preview_block,
    "preview construction cannot send data",
)

# 8. The user-facing disclosure must remain in the app and the README.
check("Off by default." in content, "in-app disclosure says telemetry is off by default")
check("never sends" in content, "in-app disclosure lists what is never sent")
check("## Opt-in anonymous usage statistics" in readme, "README has an opt-in privacy section")
check("**Why this helps.**" in readme, "README explains how the data improves compatibility")
check("**What is collected.**" in readme, "README documents the collected fields")
check("**What is never sent.**" in readme, "README documents what is never sent")
check("Preview data…" in readme, "README explains the local payload preview")
check(
    "Opting in does not remove that preview" in readme,
    "README says the preview remains available after opting in",
)
check("source IP address" in readme, "README discloses ordinary network metadata")
check(
    "enabled by default" not in (content + readme + telemetry).lower(),
    "no user-facing text claims telemetry is enabled by default",
)

if failures:
    print(f"\nPrivacy audit failed with {len(failures)} error(s).", file=sys.stderr)
    sys.exit(1)

print("\nPrivacy audit passed: telemetry is opt-in and data-minimised.")
