#!/usr/bin/env python3
"""
Install the project-scoped auto-logging hooks into existing research projects.

Finds every directory under the given scan roots that contains a `Prompts/`
sub-directory (the marker for a research-setup project), then either installs
or merges `~/.claude/scripts/project-settings-template.json` into
`<project>/.claude/settings.json`.

Default scan roots: ~/Projects ~/Tmp
Override with positional args: install-project-hooks.py /path/one /path/two

Flags:
  --dry-run        show what would change, write nothing
  --max-depth N    how deep to walk under each scan root (default 4)
  --verbose        also list projects that already have the hooks

Merge semantics: if `.claude/settings.json` exists, the script appends any of our
hook entries it is missing (UserPromptSubmit prompt-log, PostToolUse Bash run-log,
PostToolUse Edit|Write|Bash work-marker, Stop learn-nudge) to the relevant arrays
without removing or rewriting anything else. Idempotent — runs multiple times
leave the file unchanged after the first.

It also seeds `Prompts/learnings.md` and `Prompts/findings/FINDINGS_REGISTRY.md`
in each project if missing (disable with --no-seed).
"""
import argparse, json, os, sys
from pathlib import Path

TEMPLATE_PATH = Path.home() / ".claude" / "scripts" / "project-settings-template.json"
# Command-fragment signatures of every hook this template installs. A project is
# "already installed" only when ALL of them are present, so adding a new hook to
# the template makes a re-run merge it into projects that have the older subset.
HOOK_SIGNATURES = {
    "prompt-log":  ("UserPromptSubmit", "prompt-log.py"),   # UPS: verbatim prompt log
    "run-log":     ("PostToolUse",      "RUN_LOG.md"),       # PTU: verbatim script-run log
    "work-marker": ("PostToolUse",      "work-marker.py"),   # PTU: substantive-work marker
    "learn-nudge": ("Stop",             "learn-nudge.py"),   # Stop: soft learning nudge
}


def find_projects(roots, max_depth):
    seen = set()
    for root in roots:
        root = Path(root).expanduser()
        if not root.is_dir():
            continue
        root_depth = len(root.parts)
        for dirpath, dirnames, _ in os.walk(root):
            depth = len(Path(dirpath).parts) - root_depth
            if depth > max_depth:
                dirnames[:] = []
                continue
            # don't descend into Prompts/ itself or hidden / vendored dirs
            dirnames[:] = [d for d in dirnames
                           if not d.startswith(".") and d not in {"node_modules","renv","Data"}]
            if "Prompts" in dirnames:
                proj = Path(dirpath).resolve()
                if proj not in seen:
                    seen.add(proj)
                    yield proj


def missing_signatures(settings):
    """Return the set of HOOK_SIGNATURES keys NOT yet present in settings."""
    hooks = settings.get("hooks", {})
    missing = set()
    for key, (event, fragment) in HOOK_SIGNATURES.items():
        present = any(
            fragment in (h.get("command") or "")
            for entry in hooks.get(event, []) for h in entry.get("hooks", []))
        if not present:
            missing.add(key)
    return missing


def merge_hooks(existing, template):
    """Append template hooks into existing settings without duplicating."""
    if "hooks" not in existing:
        existing["hooks"] = {}
    for event, entries in template["hooks"].items():
        existing["hooks"].setdefault(event, [])
        for tmpl_entry in entries:
            tmpl_matcher = tmpl_entry.get("matcher", "")
            # find an existing entry with the same matcher, or append a new one
            target = next((e for e in existing["hooks"][event]
                           if e.get("matcher", "") == tmpl_matcher), None)
            if target is None:
                existing["hooks"][event].append(json.loads(json.dumps(tmpl_entry)))
                continue
            target.setdefault("hooks", [])
            existing_cmds = {(h.get("type"), h.get("command")) for h in target["hooks"]}
            for h in tmpl_entry["hooks"]:
                key = (h.get("type"), h.get("command"))
                if key not in existing_cmds:
                    target["hooks"].append(json.loads(json.dumps(h)))
    return existing


LEARNINGS_SEED = """\
# Learnings

> Gotchas, surprises, dead-ends, and hard-won insights for THIS project.
> Newest entry at top. Promote broadly-useful ones to global memory with
> `/transfer`. Captured via the learn-nudge Stop hook or by hand.

<!-- Entry format:
## YYYY-MM-DD — <one-line title>
- **What:** <the gotcha / insight, concretely>
- **Why it matters:** <what it saves the next session>
- **Beyond this project?** yes/no   (yes => candidate for /transfer)
-->
"""

FINDINGS_REGISTRY_SEED = """\
# Findings Registry

> Scientific findings for this project. One topic ledger per file in this
> directory (`<topic-slug>.md`); each accumulates evidence across runs.
> Maintained by `/finding`. Status: tentative | supported | refuted.

| ID | Claim | Status | Topic | Updated |
|----|-------|--------|-------|---------|
"""


def seed_scaffold(proj, dry_run):
    """Create learnings.md + findings/FINDINGS_REGISTRY.md if missing. Returns
    a list of created (relative) paths."""
    created = []
    targets = [
        (proj / "Prompts" / "learnings.md", LEARNINGS_SEED),
        (proj / "Prompts" / "findings" / "FINDINGS_REGISTRY.md", FINDINGS_REGISTRY_SEED),
    ]
    for path, content in targets:
        if path.exists():
            continue
        created.append(str(path.relative_to(proj)))
        if not dry_run:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    return created


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roots", nargs="*", default=[str(Path.home() / "Projects"),
                                                 str(Path.home() / "Tmp")])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--max-depth", type=int, default=4)
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--no-seed", action="store_true",
                    help="don't create learnings.md / findings registry")
    args = ap.parse_args()

    template = json.loads(TEMPLATE_PATH.read_text())

    n_new = n_merged = n_skipped = n_seeded = 0
    for proj in sorted(find_projects(args.roots, args.max_depth)):
        settings_path = proj / ".claude" / "settings.json"
        if settings_path.exists():
            try:
                existing = json.loads(settings_path.read_text())
            except json.JSONDecodeError as e:
                print(f"  SKIP (malformed JSON): {settings_path}: {e}", file=sys.stderr)
                continue
            missing = missing_signatures(existing)
            if not missing:
                if args.verbose:
                    print(f"  ok  {proj}  (hooks already installed)")
                n_skipped += 1
            else:
                merged = merge_hooks(existing, template)
                print(f"  MERGE {proj}  (+{','.join(sorted(missing))})")
                if not args.dry_run:
                    settings_path.write_text(json.dumps(merged, indent=2) + "\n")
                n_merged += 1
        else:
            print(f"  NEW   {proj}")
            if not args.dry_run:
                settings_path.parent.mkdir(parents=True, exist_ok=True)
                settings_path.write_text(json.dumps(template, indent=2) + "\n")
            n_new += 1

        if not args.no_seed:
            created = seed_scaffold(proj, args.dry_run)
            if created:
                print(f"        seed: {', '.join(created)}")
                n_seeded += 1

    tag = "[dry-run] " if args.dry_run else ""
    print(f"\n{tag}new={n_new}  merged={n_merged}  already-installed={n_skipped}  seeded={n_seeded}")


if __name__ == "__main__":
    main()
