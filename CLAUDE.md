# Claude Code Guidelines – Vanity Expense Logbook

## AI Review Process

This project uses a **hybrid AI review gate** on every pull request.
Both reviews must be present with `DoD status: PASS`, `Blocker: 0`, `Major: 0`
before a PR can be merged.

### Claude Review (local – performed by Claude Code)

Claude Code performs the review **locally** before the PR is merged.

Steps:
1. Fetch the PR diff via `gh pr diff <number>`
2. Analyse the diff as a senior iOS/Swift reviewer
3. Post the result as a PR comment using `gh pr comment <number> --body "..."`

The comment must follow this exact format:

```
### Claude

DoD status: PASS
Blocker: 0
Major: 0

<review text>
```

Only raise `DoD status: FAIL` or `Blocker`/`Major` above 0 when real defects
that must be fixed before merging are found.

### ChatGPT Review (automated – GitHub Actions)

ChatGPT review is generated automatically by the `ai-review` job in
`vanity-dev-engine` (repo-pipeline.yml). It uses the `OPENAI_API_KEY` secret
stored in the repository's GitHub Actions secrets.

Secret location: **Settings → Secrets and variables → Actions → `OPENAI_API_KEY`**

## Versioning Convention

Every PR must bump `MARKETING_VERSION` in `CamperLogBook.xcodeproj/project.pbxproj`.

Build number format: `JJ.Major.MinorPatch`
- `JJ` = last two digits of the year (e.g. 26 for 2026)
- `Major` = major version number
- `MinorPatch` = minor + patch concatenated (e.g. version 2.6.0 → build 26.2.60)

## CI Pipeline

Reusable workflow: `OliverGiertz/vanity-dev-engine` (repo-pipeline.yml)

Jobs:
- **ci**: lint, build, test (platform-specific defaults for iOS/Node/Python)
- **security-scan**: Gitleaks secret scan + Semgrep SAST + Dependency Review (PRs only)
- **ai-review**: ChatGPT comment generation + validation of both Claude & ChatGPT reviews

The pipeline is only active when the repository variable `USE_VANITY_DEV_ENGINE` is set to `true`.
