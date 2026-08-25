# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- `README.md`'s "Provider Pins" table and `CLAUDE.md`'s module structure line both said Terraform `= 1.7.5` — `providers.tf` actually pins `= 1.10.5`, matching the platform-wide Terraform 1.10.5 / S3-native-locking migration already reflected everywhere else. Same stale-version pattern already found and fixed in `aj-tf-module-vpc` and `aj-tf-module-eks`.
- `README.md`'s Usage example and `skills.md`'s "Stable ref" pointed at two different, both-wrong org names (`github.com/ajay/...` and `github.com/ajaylakma/...` respectively) — neither matches the real org `ajay-infra`. `skills.md` also referenced a branch `aurora-01` that doesn't exist (only `main` exists locally — confirmed via `git branch -a`). Same pattern already found 3+ times this project (`aj-tf-module-scps`, `aj-tf-module-vpc`, `aj-tf-module-eks`, the old `my-infra`). Fixed both to `github.com/ajay-infra/aj-tf-module-aurora?ref=v1.0.0` and cut the `v1.0.0` tag (this module was fully implemented with no prior release).
- `README.md`'s "Versioning" section claimed "CI auto-tags patch on merge to main" as an active behavior — the `auto-tag` job in `.github/workflows/ci.yml` is actually commented out, pending an AWS OIDC role + state bucket. This is also why the repo had zero git tags despite two different docs referencing tags/refs that don't exist. Corrected to describe the job as defined-but-inactive.
- `skills.md`'s "AWS tags applied" listed `Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer` — checked `locals.tf`: the real tag set is `Project`/`ManagedBy`/`Repository` (from `common_tags`) plus `Environment`/`Team`/`CostCenter`/`ClusterName`/`AZCount`/`FinOpsRIFamily` (from `locals.full_tags`). No `Env`, `Model`, or `Customer` tag exists anywhere in this module. Same pattern already found in `aj-tf-module-eks`'s `skills.md`.

## [v1.0.0] - 2026-08-24

Initial release — Aurora PostgreSQL 16 + pgvector, RDS IAM auth, blue/green SG toggle, Secrets Manager connection bundle, Graviton 4 (`db.r8g.*`) FinOps strategy. Module was already fully implemented; this tag just formalizes the first stable release so `README.md`/`skills.md` have something real to pin to.
