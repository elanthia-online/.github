# elanthia-online/.github

Shared CI and repository standards for Elanthia Online projects.

| Path | What it is |
|---|---|
| `.github/workflows/ruby-ci.yml` | Shared lint and test workflow. Repos call it from their own `ci.yml`, pinned to a release (see [Versions and releases](#versions-and-releases)). |
| `rubocop/` | Master copy of the shared RuboCop rules (`base.yml`) and the custom ASCII cop. Each repo keeps a byte-identical copy under `.rubocop/`, and the shared workflow fails if a copy differs. |
| `rulesets/` | Branch and tag protection definitions. |
| `bin/apply-rulesets` | Applies the rulesets and shared repository settings. Run by an admin after a change to `rulesets/` merges; see the comment at the top of the script. |
| `bin/sync-lockfile` | Aligns a repo's `Gemfile.lock` and `.ruby-version` with lich-5's, or checks that they are aligned (`--check`). See the comment at the top of the script. |
| `.github/workflows/lockfile-sync.yml` | Shared check that runs `bin/sync-lockfile --check`. Repos call it from their own `ci.yml`, pinned to a release like `ruby-ci.yml`, and list it in `ci-gate`. |

Changing the shared RuboCop rules means updating `rubocop/` and the two hashes in `ruby-ci.yml` together (`self-check.yml` enforces this). Each repo then copies the new files in the PR that moves its pin to the release with the change (see below).

## Versions and releases

Repos pin a release, never a branch: the full commit SHA of a release tag, with the version as a comment on the same line.

```yaml
uses: elanthia-online/.github/.github/workflows/ruby-ci.yml@<sha> # v1.0.0
```

Each repo's Dependabot (`github-actions` at `/`) sees newer release tags and opens a PR that changes the SHA and the comment together. A change merged to `main` reaches the repos only when it ships in a release.

- **Versions follow semver.** A minor or patch release is compatible: a bumped action, a fix, a new optional input. A major release changes the interface: a renamed or removed input, or behaviour a repo has to react to. Its release notes say what each repo must change.
- **Tags never move.** The `release tags` ruleset blocks updating or deleting `v*` tags, so every release is a new tag (`v1.1.0`). There is no floating `v1`.
- **To release,** merge to `main`, then tag the merge commit and publish a release on that tag, with notes on what the repos pick up:

  ```
  git push origin <sha>:refs/tags/vX.Y.Z
  gh release create vX.Y.Z --verify-tag --title vX.Y.Z --notes-file notes.md
  ```

  Push the tag with git first. Creating it through the API (`gh release create --target`) returned 404 for an admin token without the `workflow` scope when v1.0.0 was cut.
- **A RuboCop rule change needs a hand.** If a release changes `rubocop/base.yml` or `rubocop/cops/`, the hashes in `ruby-ci.yml` change with it, and a repo's lint fails until its `.rubocop/` copies match. Dependabot only moves the pin, so its bump PR goes red. Say so in the release notes, and push the copied files to each bump PR.

## Gem versions follow lich-5

lich-5 is the reference for gem versions. Every other Ruby repo locks the gems it shares with lich-5 at lich-5's versions, with the same Bundler (`BUNDLED WITH`), the same `PLATFORMS` list and the same `.ruby-version`. Gems a repo has that lich-5 doesn't are its own business.

- To change a shared gem, Bundler or Ruby, change lich-5 first. When that merges, align each other repo by running this in it and committing the result:

  ```
  curl -fsSL https://raw.githubusercontent.com/elanthia-online/.github/main/bin/sync-lockfile | ruby -
  ```

  It needs lich-5's Bundler version installed and prints the `gem install` command if it isn't.
- On a pull request, `lockfile-sync.yml` fails only if the PR adds drift. A Dependabot bump of a shared gem fails, for example, because that fix belongs in lich-5. Drift the base branch already has is reported but doesn't fail, so a lich-5 update never blocks unrelated PRs.
- On a push to the default branch, or a scheduled run, any drift fails.
