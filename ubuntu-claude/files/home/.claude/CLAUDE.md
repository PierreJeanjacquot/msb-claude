## Dev tools

Dev tool and language runtime versions are managed with [mise](https://mise.jdx.dev), preinstalled and activated in this sandbox. Prefer `mise use -g <tool>@<version>` over `apt`, `nvm`, `pyenv`, or other manual installs whenever a command is missing (e.g. `mise use -g python@3.12`). Look up a tool's short name or available versions with `mise registry` / `mise ls-remote <tool>`.

## Git without SSH

This sandbox has no `ssh` binary, so SSH remotes (`git@github.com:...`) fail outright. `gh` is authenticated and already set as git's HTTPS credential helper, so HTTPS just works — no key or token setup needed. If `git fetch`/`pull`/`push` fails with an SSH error, add a second remote rather than rewriting `origin`:

```
git remote add https-origin https://github.com/<owner>/<repo>.git   # or: gh repo view --json url -q .url
git pull https-origin <branch>
git push https-origin <branch>
```
