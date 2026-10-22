# release-cut

Cut order is merge → tag → changelog → flag cleanup. Never reorder.

## Order

1. **tag** — SemVer tag next; tag-as-truth (no tag = no release). Merge already completed at workflow step 2 (gate-merge + merge). The cut starts at tag after a verified merge, as the `--no-merge` path does.
2. **tag** — SemVer tag next; tag-as-truth (no tag = no release).
3. **changelog** — impact-grouped tracker notes (Added / Fixed / Deprecated /
   Removed / Security) generated after the tag, approved via dry-run preview.
4. **flag cleanup** — rollout flags removed last.

## SemVer decision tree

- Patch: bug fixes, no API change.
- Minor: backward-compatible additions or deprecations.
- Major: breaking changes or removals.

## Tag as truth

The tag is the release's identity. Notes, packets, and records all key off
the tag; anything without a tag is not a release.

## Dry-run preview

Every mutating cut step runs a dry-run preview first: show the tag name, the
grouped notes, and the cleanup list; proceed only on explicit confirmation.

## Handoff packet

Each release ships a monitor handoff packet: tag, verdict history, threshold
readings, notes pointer. Continuous monitoring starts from the packet in
`factory-monitor` — never inside this run.

## Deploy record and idempotency

The `deploy-record/1` versioned schema carries the cut; every step has an
idempotency key so retries never double-cut. Governance is lenient-additive:
new optional fields never break old readers.

## --no-merge path

On the pre-merged path the cut starts at tag — but only after verifying the
merged SHA is the exact reviewed head.
