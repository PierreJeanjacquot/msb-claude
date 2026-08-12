# msb-claude

A Docker image (`ubuntu-claude`) with [Claude Code](https://claude.com/claude-code) preinstalled, meant to be run as a [microsandbox](https://microsandbox.dev) (`msb`) microVM. It gives you a disposable, isolated sandbox where Claude Code can run and act (read/write files, execute commands, hit the network) without touching your host machine.

## Contents

- `ubuntu-claude/Dockerfile` — builds on top of `ubuntu`, installs Claude Code, skips the interactive onboarding (auth is handled via a token, see below), and sets up a default status line.
- `ubuntu-claude/files/` — files copied into the image by the Dockerfile, laid out under `home/` to mirror their destination path relative to `/home/ubuntu` (e.g. `files/home/.gitconfig` → `~/.gitconfig`).

## Prerequisites

- **microsandbox (`msb`)** installed and working (requires hardware virtualization — KVM on Linux, Apple Silicon on macOS). Full setup instructions: [docs.microsandbox.dev](https://docs.microsandbox.dev).
- **Docker** installed on your host — used only to _build_ the image locally, msb doesn't need a running Docker daemon to run it.
- **Claude Code installed on your host machine**, with an active Claude subscription (or API access) — needed once, to generate the authentication token below.

## 1. Generate a Claude Code authentication token

On your **host** (not inside a sandbox), with Claude Code already installed and logged in:

```bash
claude setup-token
```

This prints a `CLAUDE_CODE_OAUTH_TOKEN`. It lets Claude Code authenticate non-interactively — no login flow needed inside the sandbox. Export it in the shell you'll use to create sandboxes (or keep it in a local `.env` you `source` — never commit it):

```bash
export CLAUDE_CODE_OAUTH_TOKEN=<token>
```

## 2. Build the image and load it into msb

```bash
docker build ubuntu-claude/ -t ubuntu-claude && docker save ubuntu-claude | msb load
```

No registry involved: the image is built locally with Docker, then piped straight into msb's local image cache via `msb load`.

## 3. Create a sandbox

```bash
msb create \
  --name ubuntu-msb \
  --net public \
  -v ${PWD}:${PWD} \
  --workdir ${PWD} \
  --cpus 2 --max-cpus 8 \
  --memory 4G --max-memory 8G \
  --secret "CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com" \
  ubuntu-claude
```

- `--name ubuntu-msb` — name of the sandbox, used to find/reuse it (`msb exec`, `msb rm`, ...).
- `--net public` — allow all outbound network access. See the [Network isolation](#network-isolation) cookbook for a more restricted setup.
- `-v ${PWD}:${PWD}` — bind-mount the current directory into the sandbox at the same path (use absolute path to avoid dynamic resolution change).
- `--workdir ${PWD}` — working directory inside the sandbox, aligned with the mount above.
- `--cpus 2 --max-cpus 8` / `--memory 4G --max-memory 8G` — baseline / burst resource limits.
- `--secret "CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com"` — reads `$CLAUDE_CODE_OAUTH_TOKEN` from your host shell (step 1) and makes it available to the sandbox, scoped to `api.anthropic.com` only. See the [secrets documentation](https://docs.microsandbox.dev/sandboxes/secrets.md) for the full trust model.
- `ubuntu-claude` — the image built and loaded in step 2.

The sandbox boots and stays idle, ready for `msb exec`.

## 4. Attach to the sandbox

```bash
msb exec ubuntu-msb -- bash
```

Opens a shell inside the running sandbox. From there, just run `claude` as usual — it's preinstalled and already authenticated via the injected token.

## 5. Remove the sandbox

```bash
msb rm ubuntu-msb
```

Stops (if needed) and removes the sandbox and its state. The `ubuntu-claude` image stays cached in msb — recreate a sandbox from it anytime with step 3.

## Cookbook

### Adding skills

To make [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills) from your host available inside the sandbox, mount your skills directory read-only at `/home/ubuntu/.host/.agents/skills`. That specific path is expected by a `SessionStart` hook (`files/home/.claude/hooks/relink-skills.sh`), which scans it on every session start and symlinks each skill directory it finds into `~/.claude/skills` — no manual symlinking needed. The example below assumes skills are managed with [`npx skills`](https://www.npmjs.com/package/skills) installed globally on the host, which keeps them under `~/.agents/skills`:

```bash
msb create \
  --name ubuntu-msb \
  --net public \
  -v ${PWD}:${PWD} \
  -v ${HOME}/.agents/skills:/home/ubuntu/.host/.agents/skills:ro \
  --workdir ${PWD} \
  --cpus 2 --max-cpus 8 \
  --memory 4G --max-memory 8G \
  --secret "CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com" \
  ubuntu-claude
```

- `-v ${HOME}/.agents/skills:/home/ubuntu/.host/.agents/skills:ro` — mounts the host's skills directory read-only at the expected path. Adjust the source path to wherever your skills actually live; the destination must stay `/home/ubuntu/.host/.agents/skills` for the relink hook to pick it up.

The hook only manages symlinks it created itself: it leaves alone anything that's already a real file/dir or a symlink pointing elsewhere at the same name in `~/.claude/skills`, and it removes symlinks it previously created once their source skill disappears from the mount. It re-runs on every session start, so adding, removing, or updating skills on the host only requires restarting the Claude Code session inside the sandbox — not recreating it.

Volumes can only be set at `msb create` time (not added later with `msb modify`) — remove and recreate the sandbox if you need to change the mount.

### GitHub setup

The image ships with [`gh`](https://cli.github.com) preconfigured to authenticate git over HTTPS (`files/home/.gitconfig` wires `credential.helper` to `gh auth git-credential` for `github.com` and `gist.github.com`), plus a `PreToolUse` hook (`files/home/.claude/hooks/setup-git-identity-from-gh.sh`) that runs before `git add`/`git commit` and fills in whichever of git `user.name`/`user.email` isn't already set, from the authenticated `gh` account — any value you've already configured is left untouched. This lets Claude push commits, open PRs, and use `gh` commands from inside the sandbox.

On your **host**, generate a token `gh` can use non-interactively, e.g. from an account already logged in via `gh auth login`:

```bash
export GH_OAUTH_TOKEN=$(gh auth token)
```

Then create the sandbox as in step 3, adding two `--secret` flags for that token — one per host `gh` talks to (`github.com` for git/credential operations, `api.github.com` for `gh api`/`gh pr`/... calls):

```bash
msb create \
  --name ubuntu-msb \
  --net public \
  -v ${PWD}:${PWD} \
  --workdir ${PWD} \
  --cpus 2 --max-cpus 8 \
  --memory 4G --max-memory 8G \
  --secret "CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com" \
  --secret "GH_OAUTH_TOKEN@api.github.com" \
  --secret "GH_OAUTH_TOKEN@github.com" \
  ubuntu-claude
```

- `--secret "GH_OAUTH_TOKEN@api.github.com"` / `--secret "GH_OAUTH_TOKEN@github.com"` — reads `$GH_OAUTH_TOKEN` from your host shell and makes it available to the sandbox, scoped to those two hosts only (`files/home/.config/gh/hosts.yml` references it as `$MSB_GH_OAUTH_TOKEN`, the placeholder `msb` injects for a secret bound this way — see the [secrets documentation](https://docs.microsandbox.dev/sandboxes/secrets.md)).

If `GH_OAUTH_TOKEN` isn't set, `gh` inside the sandbox has no credentials: `gh auth git-credential` fails, so git operations over HTTPS and the identity-setup hook fail too.

### Network isolation

To restrict the sandbox's network access to only the Anthropic API (instead of full outbound access), replace `--net public` with `--no-net` plus a `--net-rule` allowing just that destination:

```bash
msb create \
  --name ubuntu-msb-isolated \
  --no-net \
  --net-rule "allow@api.anthropic.com:tcp:443" \
  -v ${PWD}:${PWD} \
  --workdir ${PWD} \
  --cpus 2 --max-cpus 8 \
  --memory 4G --max-memory 8G \
  --secret "CLAUDE_CODE_OAUTH_TOKEN@api.anthropic.com" \
  ubuntu-claude
```

- `--no-net` — disables outbound network access by default (replaces `--net public`).
- `--net-rule "allow@api.anthropic.com:tcp:443"` — allows traffic to `api.anthropic.com` on TCP/443 only, isolating the sandbox while still letting Claude Code reach the API.

⚠️ This network isolation doesn't block everything: Claude Code's `Web Search` tool goes through an Anthropic-hosted backend (not the sandbox's own network), so it can still perform web searches even with `--no-net`.

Network policies can only be set at `msb create` time (not added later with `msb modify`) — remove and recreate the sandbox if you need to change them.

## Going further

A few other `msb` commands that are handy while experimenting (see [CLI overview](https://docs.microsandbox.dev/cli/overview.md) for the full reference):

```bash
msb ls                  # list all sandboxes
msb ps -a               # status of running (and, with -a, stopped) sandboxes
msb inspect <sandbox>   # detailed config/status of a sandbox
msb metrics -wa         # live CPU/memory/disk/network usage, all sandboxes
msb logs <sandbox>      # captured stdout/stderr of a sandbox
msb copy <SRC> <DST>    # copy files host<->sandbox or sandbox<->sandbox (prefix sandbox-side paths with `name:`)
```
