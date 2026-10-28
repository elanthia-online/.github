# Contributing to Elanthia Online projects

Thanks for helping. These guidelines apply to every Elanthia Online repository that doesn't have its own CONTRIBUTING file.

## Pull requests

- Fork the repository, make your change on a branch, and open a pull request against the default branch. The default branch is protected: changes land through pull requests only, and merges are squashed.
- Use a [Conventional Commits](https://www.conventionalcommits.org/) title, e.g. `fix(herbhunt): v1.4.1 wait long enough for hands to empty`. lich-5 also requires one of its scopes: `all`, `dr`, `gs`, `main` or `pre/beta...`.
- Keep pull requests small and focused. A bug fix with a test is easier to review than a fix bundled with a refactor.
- If a script has a version and changelog in its header, bump the version and add a changelog line.

## Checks

Every pull request must pass the `ci-gate` check, which sums up the repository's CI jobs: lint, tests and any repo-specific checks.

Before pushing, run the same checks locally:

```sh
bundle install
bundle exec rubocop
bundle exec rspec
```

- The Ruby version CI uses is in `.ruby-version`.
- RuboCop is pinned to an exact version in the `Gemfile`; use it through `bundle exec`, because a different version can disagree with CI.
- The RuboCop rules are shared across Elanthia Online repositories. `.rubocop/base.yml` and `.rubocop/cops/` are byte-identical copies of the masters in [elanthia-online/.github](https://github.com/elanthia-online/.github), and CI fails if they differ. Don't edit them in a repository; propose rule changes in `elanthia-online/.github`. A repository's `.rubocop.yml` may only list files to exclude.

## Workflows

Changes under `.github/` (workflows and CI configuration) are owned by the Elanthia Online admins, because workflows can publish releases and use repository secrets.

## Security issues

Please don't report security problems in public issues. See [SECURITY.md](SECURITY.md).
