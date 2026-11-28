# Slugification Rules

Decision Record IDs and filenames are derived from their titles using the following slugification rules.

## The Rule

1. **Lowercase**: Convert all characters to lowercase.
2. **ASCII-fold**: Fold non-ASCII Unicode characters to their closest ASCII equivalent (e.g., `é` → `e`).
3. **Sanitize**: Replace all non-alphanumeric characters (including spaces and punctuation) with a single hyphen `-`.
4. **Collapse**: Replace consecutive hyphens with a single hyphen.
5. **Trim**: Remove leading and trailing hyphens.
6. **Truncate**: Limit the resulting string to a maximum of 60 characters.
7. **Validate**: If the result is empty, return an error.

## Collision Handling

If a record with the same slug already exists in the target directory (drafts or memory):

1. Append a numeric suffix starting from `-2` (e.g., `my-slug-2`, `my-slug-3`).
2. Suffixes are never reused; the next available number is used.

## Amendments

Amendments follow the pattern: `<original-slug>-amendment-<N>` where `<N>` is the amendment number.

## Worked Examples

| Original Title | Slug |
|----------------|------|
| Agent-Agnostic Process Engine! | agent-agnostic-process-engine |
| Café & Workspace | cafe-workspace |
| This is a very long title that will certainly exceed the sixty character limit | this-is-a-very-long-title-that-will-certainly-exceed-the-six |
| 100% Reliability | 100-reliability |
| --- | (Error: empty result) |
