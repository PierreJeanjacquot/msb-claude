# Contributing

## Linting Dockerfiles

Dockerfiles are linted with [hadolint](https://github.com/hadolint/hadolint), pinned via this repo's `mise.toml`/`mise.lock` (see the [Dev tools](README.md#dev-tools) cookbook for how `mise` version-pinning works). Run it locally with:

```bash
mise run lint:docker
```

This lints the Dockerfiles listed explicitly in the `lint:docker` task (currently just `ubuntu-claude/Dockerfile`) and is the same command CI runs on every pull request and every push to `main` (`.github/workflows/lint-dockerfile.yml`), so a clean local run means a clean CI run.

Adding a new Dockerfile to the repo? Add it to the `run` command in the `lint:docker` task in `mise.toml` — it isn't picked up automatically.

### Ignoring a hadolint rule

There's no `.hadolint.yaml` — rules are ignored per line, with an inline pragma directly above the instruction, immediately preceded by a comment explaining why:

```dockerfile
### DL3066: named user is intentional - sudoers, homedir, and ownership are all keyed to "ubuntu", not a numeric uid
# hadolint ignore=DL3066
USER ubuntu
```

One `### CODE: reason` line per ignored rule, directly above the `# hadolint ignore=...` pragma, which must itself be the line immediately preceding the instruction — nothing else in between. To ignore several rules on the same instruction, stack one `### CODE: reason` line per rule, but keep a single pragma line with all codes comma-separated (`# hadolint ignore=CODE1,CODE2`) — hadolint does not accumulate multiple separate pragma lines, only the one directly adjacent to the instruction is honored.
