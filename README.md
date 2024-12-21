# dirty-waters-action

## GitHub Action Usage

Add this workflow to your repository to analyze dependencies in your pull requests:

```yaml
name: Dirty Waters Analysis
on:
  pull_request:
    paths:
      - 'package.json'
      - 'package-lock.json'
      - 'yarn.lock'
      - 'pnpm-lock.yaml'
      - 'pom.xml'
jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: chains-project/dirty-waters-action@v1
        with:
          project_repo: ${{ github.repository }}
          version_old: ${{ github.event.pull_request.base.ref }}
          version_new: ${{ github.event.pull_request.head.ref }}
          package_manager: npm
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```


The action will:
1. Run on pull requests that modify dependency files
2. Analyze dependencies for software supply chain issues
3. Post results as a PR comment
4. Break CI if high severity issues are found
5. Upload detailed reports as artifacts

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| project_repo | Repository name (owner/repo) | Yes | - |
| version_old | Base version/ref to analyze | Yes | - |
| version_new | New version/ref for diff analysis | No | - |
| package_manager | Package manager (npm, yarn-classic, yarn-berry, pnpm, maven) | Yes | - |
| fail_on_high_severity | Fail CI on high severity issues | No | true |
| comment_on_pr | Post results as PR comment | No | true |
