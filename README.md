# elanthia-online/.github

Shared CI and repository standards for Elanthia Online projects.

| Path | What it is |
|---|---|
| `.github/workflows/ruby-ci.yml` | Shared lint and test workflow. Repos call it from their own `ci.yml`, pinned by full commit SHA: `uses: elanthia-online/.github/.github/workflows/ruby-ci.yml@<sha>`. |
| `rubocop/` | Master copy of the shared RuboCop rules (`base.yml`) and the custom ASCII cop. Each repo keeps a byte-identical copy under `.rubocop/`, and the shared workflow fails if a copy differs. |
| `rulesets/` | Branch and tag protection definitions. |
| `bin/apply-rulesets` | Applies the rulesets and shared repository settings. Run by an admin after a change to `rulesets/` merges; see the comment at the top of the script. |

Changing the shared RuboCop rules means updating `rubocop/` and the two hashes in `ruby-ci.yml` together (`self-check.yml` enforces this). Each repo then copies the new files and bumps its pinned SHA in the same PR.
