# dirty-waters-action

This action runs [Dirty Waters](https://github.com/chains-project/dirty-waters) on your repository to analyze dependencies for Software Supply Chain (SSC) issues.
Add this workflow to your repository to analyze dependencies in your pull requests
(change/add inputs as needed -- details in [action.yml](./action.yml)). An example of a workflow that uses this action is available in [.github/workflows/dirty-waters.yml](./.github/workflows/dirty-waters.yml).

The action will:

<!-- TODO: make sure this first point is correct -->

1. Run on commits that modify dependency files (OR in the first commit after the action is added)
2. Analyze dependencies for software supply chain issues
3. Post results:
   1. If in a PR, will post the report as a comment
   2. Otherwise, results are available in the action logs; if high severity issues are found, the report will be posted as a comment in the commit, if enabled
4. Break CI if high severity issues are found, if enabled

As an important note, **the first time you run this action, it _will_ take quite some time**!
However, after the first run, subsequent ones should be fast.

SSC issues currently checked for:

- No source code links (or invalid ones) for a dependency
- Provided release tag not found in a dependency's repository
- Dependency being a fork of another package
- Deprecated dependency
- Dependency without build attestation
- Dependency without code signature (or an invalid one)

### Inputs

| Input                 | Description                                                                                        | Required | Default        |
| --------------------- | -------------------------------------------------------------------------------------------------- | -------- | -------------- |
| github_token          |                                                                                                    | Yes      | -              |
| dirty_waters_version  | Dirty Waters version to use                                                                        | No       | latest         |
| project_repo          | Repository name (owner/repo)                                                                       | Yes      | -              |
| version_old           | Base version/ref to analyze,                                                                       | No       | HEAD           |
| version_new           | New version/ref for diff analysis                                                                  | No       | HEAD^          |
| differential_analysis | Whether to perform differential analysis (true/false)                                              | No       | false          |
| package_manager       | Package manager (npm, yarn-classic, yarn-berry, pnpm, maven)                                       | Yes      | -              |
| name_match            | Compare the package names with the name in the in the package.json file. Will slow down execution. | No       | false          |
| pnpm_scope            | Extract dependencies from pnpm with a specific scope                                               |          | -              |
| specified_smells      | Specify the smells to check for                                                                    | No       | all            |
| debug                 | Enable debug mode                                                                                  | No       | false          |
| no_gradual_report     | Disable gradual report functionality                                                               | No       | false          |
| fail_on_high_severity | Fail CI on high severity issues                                                                    | No       | true           |
| x_to_fail             | Percentage threshold to break CI on non-high severity issues (per type of issue)                   | No       | 5% of packages |
| allow_pr_comment      | Comment on PR if high severity issues found                                                        | No       | true           |
| comment_on_commit     | Comment on commit if high severity issues found                                                    | No       | false          |
