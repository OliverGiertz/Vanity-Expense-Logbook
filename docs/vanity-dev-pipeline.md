# Vanity Development Pipeline
AI Assisted Development Workflow

Version: 1.0  
Scope: Vanity Ecosystem Repositories

---

# 1 Scope

This document defines the development workflow for all repositories in the **Vanity ecosystem**.

Excluded repository:

PremiraSyncTool

This repository is company-internal and not part of the Vanity ecosystem.

---

# 2 Goal

Ensure high code quality, maintainability and security using:

- automated CI pipelines
- security scanning
- AI-assisted code review
- enforced GitHub pull request policies
- standardized repository practices

This document acts as the **authoritative development policy** for all AI agents and contributors.

---

# 3 Definition of Done (DoD)

A task or pull request is considered complete **only if ALL conditions below are met**.

1 Implementation complete  
2 Tests pass  
3 Lint / formatting checks pass  
4 Security scans pass  
5 AI code reviews pass  
6 No unresolved findings remain  
7 CI pipeline finished successfully  

If any issue is reported:

Fix issue → run pipeline again → repeat review.

---

# 4 Mandatory Pipeline Checks

Every pull request must pass the following checks.

## 4.1 CI

Minimum CI requirements:

- build
- lint
- formatting
- tests

Optional but recommended:

- type checking
- coverage reporting

---

## 4.2 Security

Security scanning must include at least:

Semgrep (SAST)  
Dependency vulnerability scanning  

Recommended tooling:

Semgrep  
GitHub Dependabot  

Optional additions:

Trivy  
Snyk  
Bandit (Python)  
npm audit (Node)  
dotnet vulnerability check (.NET)

False positives may occur and must be evaluated before suppression.

---

# 5 AI Code Review

Two independent AI reviewers must review the pull request diff.

AI reviewers must only analyze **actual code changes**.

---

## Reviewer 1

ChatGPT Review Agent

Focus areas:

- architecture
- logic correctness
- maintainability
- readability
- refactoring opportunities

---

## Reviewer 2

Claude Review Agent

Focus areas:

- security risks
- edge cases
- regression risks
- hidden failure scenarios

---

# 6 AI Review Output Format

All AI reviewers MUST produce output in the following format.

Summary

Findings

Blocker  
Major  
Minor  

Suggested Fixes

Risk Notes

Final Status

PASS  
FAIL

---

# 7 Severity Definition

Blocker

Critical issue that may cause:

- security vulnerability
- data loss
- broken functionality
- system instability

Major

Important issue affecting:

- architecture
- maintainability
- performance
- reliability

Minor

Improvement suggestion:

- style
- clarity
- refactoring
- documentation

---

# 8 Review Rules

PASS allowed only if:

no Blocker findings  
no Major findings  

If FAIL occurs:

Issues must be fixed  
Pipeline must run again  
Review must be executed again

If a review process crashes or fails:

Review does NOT count as approved.

It must be executed again.

---

# 9 Pull Request Policy

All code changes must go through a pull request.

Direct commits to protected branches are not allowed.

A PR cannot be merged until:

CI pipeline passes  
Security scans pass  
ChatGPT review PASS  
Claude review PASS  
All findings resolved  

---

# 10 GitHub Enforcement

Branch protection rules must enforce:

Require pull request before merge  
Require status checks  
Require branch up-to-date  

Required status checks:

ci  
security-scan  
ai-review  

Optional but recommended:

require conversation resolution  
require linear history  

---

# 11 GitHub Workflow Overview

Typical CI pipeline:

commit  
 ↓  
lint  
 ↓  
tests  
 ↓  
security scan  
 ↓  
AI review  
 ↓  
merge allowed  

---

# 12 Central Repository Strategy

Future baseline is a central repository:

`vanity-dev-engine`

This repository contains shared logic for all Vanity repositories:

- shared GitHub workflows
- security scanning standards
- AI review engine
- release automation

Each product repository (like CamperLogBook) should consume the central pipeline via:

`Use Vanity Dev Engine`

as a reusable workflow entrypoint.

---

# 13 Execution Model

## 13.1 Local Repository Responsibilities

Every product repository keeps:

- project-specific build and test settings
- branch protection setup
- repository secrets and environment vars
- PR template and contribution docs

## 13.2 vanity-dev-engine Responsibilities

The central engine owns:

- reusable CI templates
- reusable security jobs
- AI review orchestration
- release/tag automation
- policy validation and reporting

## 13.3 Check Names (required)

All repositories should expose these mandatory checks:

- `ci`
- `security-scan`
- `ai-review`

Branch protection must require these checks before merge.

---

# 14 Rollout Plan

Phase 1 (now):

- keep local workflows active
- enforce DoD and review format
- align check names

Phase 2 (hybrid):

- add `use-vanity-dev-engine` workflow (feature-flagged)
- run local and central checks in parallel
- compare result quality and runtime

Phase 3 (central default):

- enable `USE_VANITY_DEV_ENGINE=true`
- keep local fallback for rollback
- switch branch protection to central checks

Phase 4 (cleanup):

- remove duplicated local logic
- keep only repo-specific extensions

---

# 15 Failure Handling

If any required check fails:

fix findings  
rerun pipeline  
rerun AI reviews  
merge remains blocked until all required checks pass

If AI review tooling crashes, times out, or does not produce the mandatory output format:

review is invalid  
status remains FAIL  
review must be rerun

# 16 Summary

Every change must pass:

`ci`  
`security-scan`  
`ai-review`

Only when all required checks pass may a pull request be merged.

---

# End of Policy
