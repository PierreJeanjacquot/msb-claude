## Dev tools

Dev tool and language runtime versions are managed with [mise](https://mise.jdx.dev), preinstalled and activated in this sandbox. Prefer `mise use -g <tool>@<version>` over `apt`, `nvm`, `pyenv`, or other manual installs whenever a command is missing (e.g. `mise use -g python@3.12`). Look up a tool's short name or available versions with `mise registry` / `mise ls-remote <tool>`.
