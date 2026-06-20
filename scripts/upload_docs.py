#!/usr/bin/env python3
"""Upload markdown docs under docs/ to the autopilot docs service.

Stdlib-only. Walks docs/, parses YAML frontmatter, keeps files with a `slug`,
errors on duplicate slugs, and POSTs in batches of 50 to:

    {DOCS_ENDPOINT}/api/v1/docs/repositories/{url-encoded repo}/documents

with header `Authorization: Bearer $DOCS_UPLOAD_TOKEN` and body:

    {"documents": [{"docId": slug, "content": body}, ...]}

Environment:
    DOCS_ENDPOINT        default https://autopilot.rxlab.app
    DOCS_REPOSITORY_ID   e.g. owner/repo  (required unless --dry-run)
    DOCS_UPLOAD_TOKEN    bearer token     (required unless --dry-run)
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_ENDPOINT = "https://autopilot.rxlab.app"
BATCH_SIZE = 50
DOCS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")


def parse_frontmatter(text):
    """Return (metadata: dict, body: str). Minimal YAML: `key: value` lines."""
    if not text.startswith("---"):
        return {}, text
    lines = text.splitlines()
    if lines[0].strip() != "---":
        return {}, text
    meta = {}
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
        line = lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            value = value.strip()
            if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
                value = value[1:-1]
            meta[key.strip()] = value
    if end is None:
        return {}, text
    body = "\n".join(lines[end + 1:]).lstrip("\n")
    return meta, body


def collect_documents():
    """Walk docs/, return list of {docId, content}; error on duplicate slugs."""
    documents = []
    slugs = {}
    for root, _, files in os.walk(DOCS_DIR):
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            with open(path, "r", encoding="utf-8") as f:
                text = f.read()
            meta, body = parse_frontmatter(text)
            slug = meta.get("slug")
            if not slug:
                rel = os.path.relpath(path, DOCS_DIR)
                print(f"  skip (no slug): {rel}", file=sys.stderr)
                continue
            if slug in slugs:
                raise SystemExit(
                    f"Duplicate slug '{slug}' in {os.path.relpath(path, DOCS_DIR)} "
                    f"and {os.path.relpath(slugs[slug], DOCS_DIR)}"
                )
            slugs[slug] = path
            documents.append({"docId": slug, "content": body})
    return documents


def batched(items, size):
    for i in range(0, len(items), size):
        yield items[i:i + size]


def post_batch(endpoint, repo, token, batch):
    url = (
        f"{endpoint.rstrip('/')}/api/v1/docs/repositories/"
        f"{urllib.parse.quote(repo, safe='')}/documents"
    )
    payload = json.dumps({"documents": batch}).encode("utf-8")
    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req) as resp:
        return resp.status, resp.read().decode("utf-8")


def main():
    dry_run = "--dry-run" in sys.argv[1:]
    endpoint = os.environ.get("DOCS_ENDPOINT", DEFAULT_ENDPOINT)
    repo = os.environ.get("DOCS_REPOSITORY_ID")
    token = os.environ.get("DOCS_UPLOAD_TOKEN")

    if not os.path.isdir(DOCS_DIR):
        raise SystemExit(f"docs directory not found: {DOCS_DIR}")

    documents = collect_documents()
    if not documents:
        raise SystemExit("No documents with a `slug` found under docs/.")

    batches = list(batched(documents, BATCH_SIZE))
    print(f"Found {len(documents)} document(s) in {len(batches)} batch(es).")
    for doc in documents:
        print(f"  - {doc['docId']} ({len(doc['content'])} chars)")

    if dry_run:
        print("\n[dry-run] No network calls made. Frontmatter parsed and batches built OK.")
        return

    if not repo:
        raise SystemExit("DOCS_REPOSITORY_ID is required (e.g. owner/repo).")
    if not token:
        raise SystemExit("DOCS_UPLOAD_TOKEN is required.")

    print(f"\nUploading to {endpoint} for repository {repo} ...")
    for i, batch in enumerate(batches, 1):
        try:
            status, body = post_batch(endpoint, repo, token, batch)
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")
            raise SystemExit(f"Batch {i}/{len(batches)} failed: HTTP {e.code}\n{detail}")
        except urllib.error.URLError as e:
            raise SystemExit(f"Batch {i}/{len(batches)} failed: {e.reason}")
        print(f"  batch {i}/{len(batches)}: HTTP {status} {body}")

    print("Done.")


if __name__ == "__main__":
    main()
