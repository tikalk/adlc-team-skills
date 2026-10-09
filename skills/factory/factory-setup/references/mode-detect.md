# Mode 1: Detect from git remote

Heuristic shortcut for the common case. The remote URL is read-only input —
it is displayed, never executed beyond `git remote get-url origin`.

## Steps

1. Read the origin remote:
   ```bash
   git remote get-url origin
   ```
   No remote (or git absent) → fall through to Mode 2, no error.
2. Map the host (case-insensitive substring):
   - `github.com` → `github`
   - `gitlab.` (any self-hosted or `gitlab.com`) → `gitlab`
   - anything else (Linear/Jira have no git remote signal) → Mode 2.
3. **Always confirm**: present the guess explicitly —
   "Remote `<url>` suggests provider `gitlab`. Use it, or pick another?"
   A guess is never written unconfirmed; a wrong guess posts to the wrong
   tracker, which is the failure class this skill exists to prevent.
4. On confirmation → §Commit step (SKILL.md). On rejection → Mode 2.
