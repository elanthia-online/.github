# Contributing to Elanthia Online projects

Thanks for helping. These are the defaults for every Elanthia Online repository that doesn't have its own CONTRIBUTING file. Where a repository's README or CI says something different, follow the repository.

## Pull requests

- Fork the repository, make your change on a branch, and open a pull request against the default branch.
- Use a [Conventional Commits](https://www.conventionalcommits.org/) title, e.g. `fix(herbhunt): v1.4.1 wait long enough for hands to empty`. In scripts, the title also carries the script's new version, as in that example. lich-5 requires one of its scopes: `all`, `dr`, `gs`, `main` or `pre/beta...`.
- Keep pull requests small and focused. A bug fix with a test is easier to review than a fix bundled with a refactor.
- If a script has a version and changelog in its header, bump the version and add a changelog line.

## Checks

Before pushing, run the same checks as the repository's CI, if it has any. Its workflows in `.github/workflows/` show the exact commands, including any setup steps.

### lich-5, dr-scripts, scripts and ProfanityFE

These repositories share one Ruby CI setup and one set of branch protection rules:

- The default branch is protected. Changes land through pull requests only, every pull request must pass the `ci-gate` check (it sums up lint, tests and any repo-specific checks), review conversations must be resolved before merging, and merges are squashed.
- To run the checks locally:

  ```sh
  bundle install
  bundle exec rubocop
  bundle exec rspec
  ```

- scripts needs some setup first. Install `xmllint` (macOS includes it; on Debian or Ubuntu install `libxml2-utils`), then run `bin/migrate`, which generates the type data most specs read. Specs that read lich-5 look for a checkout in `LICH5_PATH` or a `lich-5` directory next to scripts; CI uses the lich-5 release pinned in its workflow. scripts' CI lints only the files a pull request changes, so run `bundle exec rubocop` on the files you changed.
- The Ruby version CI uses is in `.ruby-version`.
- RuboCop is pinned to an exact version in the `Gemfile`; use it through `bundle exec`, because a different version can disagree with CI.
- The RuboCop rules are shared. `.rubocop/base.yml` and `.rubocop/cops/` are byte-identical copies of the masters in [elanthia-online/.github](https://github.com/elanthia-online/.github), and CI fails if they differ. Don't edit them in a repository; propose rule changes in `elanthia-online/.github`. A repository's `.rubocop.yml` may only list files to exclude.
- Changes under `.github/` (workflows and CI configuration) are routed to the Elanthia Online admins for review, because workflows can publish releases and use repository secrets.

### Other repositories

Follow the repository's README, and its CI workflows if it has any, for setup and checks.

## Security issues

Please don't report security problems in public issues. See [SECURITY.md](SECURITY.md).
