# elanthia-online/.github

Shared CI and repository standards for Elanthia Online projects.

| Path | What it is |
|---|---|
| `.github/workflows/ruby-ci.yml` | Shared lint and test workflow. Repos call it from their own `ci.yml`, pinned by full commit SHA: `uses: elanthia-online/.github/.github/workflows/ruby-ci.yml@<sha>`. |
| `rubocop/` | Master copy of the shared RuboCop rules (`base.yml`) and the custom ASCII cop. Each repo keeps a byte-identical copy under `.rubocop/`, and the shared workflow fails if a copy differs. |
| `rulesets/` | Branch and tag protection definitions. |
| `bin/apply-rulesets` | Applies the rulesets and shared repository settings. Run by an admin after a change to `rulesets/` merges; see the comment at the top of the script. |
| `bin/sync-lockfile` | Aligns a repo's `Gemfile.lock` and `.ruby-version` with lich-5's, or checks that they are aligned (`--check`). See the comment at the top of the script. |
| `.github/workflows/lockfile-sync.yml` | Shared check that runs `bin/sync-lockfile --check`. Repos call it from their own `ci.yml`, pinned by full commit SHA, and list it in `ci-gate`. |

Changing the shared RuboCop rules means updating `rubocop/` and the two hashes in `ruby-ci.yml` together (`self-check.yml` enforces this). Each repo then copies the new files and bumps its pinned SHA in the same PR.

## Gem versions follow lich-5

lich-5 is the reference for gem versions. Every other Ruby repo locks the gems it shares with lich-5 at lich-5's versions, with the same Bundler (`BUNDLED WITH`), the same `PLATFORMS` list and the same `.ruby-version`. Gems a repo has that lich-5 doesn't are its own business.

- To change a shared gem, Bundler or Ruby, change lich-5 first. When that merges, align each other repo by running this in it and committing the result:

  ```
  curl -fsSL https://raw.githubusercontent.com/elanthia-online/.github/main/bin/sync-lockfile | ruby -
  ```

  It needs lich-5's Bundler version installed and prints the `gem install` command if it isn't.
- On a pull request, `lockfile-sync.yml` fails only if the PR adds drift. A Dependabot bump of a shared gem fails, for example, because that fix belongs in lich-5. Drift the base branch already has is reported but doesn't fail, so a lich-5 update never blocks unrelated PRs.
- On a push to the default branch, or a scheduled run, any drift fails.
