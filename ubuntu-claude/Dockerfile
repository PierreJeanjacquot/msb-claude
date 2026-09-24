### DL3006: rolling sandbox image, we deliberately track ubuntu:latest
# hadolint ignore=DL3006
FROM ubuntu
ARG DEBIAN_FRONTEND=noninteractive
SHELL [ "/bin/bash", "-o", "pipefail", "-l", "-c" ]

### DL3008: apt package versions tracked rolling on purpose, same reason as DL3006
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git jq nano sudo \
    && rm -rf /var/lib/apt/lists/* && update-ca-certificates

# add passwordless sudo for ubuntu user
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && chmod 0440 /etc/sudoers.d/ubuntu

# use non root user
### DL3066: named user is intentional - sudoers, homedir, and ownership are all keyed to "ubuntu", not a numeric uid
# hadolint ignore=DL3066
USER ubuntu
WORKDIR /home/ubuntu

# setup TERM fallback to xterm-256color when connecting host uses incompatible term
### SC2016: single quotes are intentional - literal shell written into ~/.bashrc for evaluation at container runtime, not at build time
# hadolint ignore=SC2016
RUN echo 'infocmp "$TERM" >/dev/null 2>&1 || export TERM=xterm-256color' >> ~/.bashrc

# setup claude
### SC2016: single quotes are intentional - literal shell written into ~/.bashrc for evaluation at container runtime, not at build time
# hadolint ignore=SC2016
RUN curl -fsSL https://claude.ai/install.sh | bash && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
# add claude-yolo alias
RUN echo 'alias claude-yolo="claude --dangerously-skip-permissions"' >> ~/.bashrc
# skip onboarding as we will use CLAUDE_CODE_OAUTH_TOKEN
RUN (cat ~/.claude.json 2>/dev/null || echo '{}') | jq '.hasCompletedOnboarding = true' > /tmp/claude.json.tmp && mv /tmp/claude.json.tmp ~/.claude.json
# setup default status line
COPY --chown=ubuntu:ubuntu files/home/.claude/statusline-default.sh .claude/
RUN (cat ~/.claude/settings.json 2>/dev/null || echo '{}') | jq '.statusLine = {"type": "command", "command": "if [ -f $HOME/.claude/statusline.sh ]; then bash $HOME/.claude/statusline.sh; else bash $HOME/.claude/statusline-default.sh; fi"}' > /tmp/settings.json.tmp && mv /tmp/settings.json.tmp ~/.claude/settings.json
# setup skills relink from ~/.host/.agents/skills/
RUN mkdir -p .claude/hooks
COPY --chown=ubuntu:ubuntu files/home/.claude/hooks/relink-skills.sh .claude/hooks/
RUN jq '.hooks.SessionStart += [{"hooks":[{"type":"command","command":"bash \"$HOME/.claude/hooks/relink-skills.sh\"","timeout":15}]}]' ~/.claude/settings.json > /tmp/settings.json.tmp && mv /tmp/settings.json.tmp ~/.claude/settings.json

# setup git via gh
### DL3004: sudo is intentional - this image grants the sandbox user passwordless sudo, that's the whole point of this image
# hadolint ignore=DL3004
RUN sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && curl -fsSL -o "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends gh \
    && sudo rm -rf /var/lib/apt/lists/*
RUN mkdir -p .config/gh
COPY --chown=ubuntu:ubuntu files/home/.config/gh/config.yml .config/gh/
COPY --chown=ubuntu:ubuntu files/home/.config/gh/hosts.yml .config/gh/
COPY --chown=ubuntu:ubuntu files/home/.gitconfig ./
RUN mkdir -p .claude/hooks
COPY --chown=ubuntu:ubuntu files/home/.claude/hooks/setup-git-identity-from-gh.sh .claude/hooks/
RUN jq '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","if":"Bash(git add *)","command":"bash \"$HOME/.claude/hooks/setup-git-identity-from-gh.sh\"","timeout":30},{"type":"command","if":"Bash(git commit *)","command":"bash \"$HOME/.claude/hooks/setup-git-identity-from-gh.sh\"","timeout":30}]}]' ~/.claude/settings.json > /tmp/settings.json.tmp && mv /tmp/settings.json.tmp ~/.claude/settings.json

# setup mise
### SC2016: single quotes are intentional - literal shell written into ~/.bashrc for evaluation at container runtime, not at build time
# hadolint ignore=SC2016
RUN curl https://mise.run | sh && echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc

# setup node
### DL3004: sudo is intentional - this image grants the sandbox user passwordless sudo, that's the whole point of this image
# hadolint ignore=DL3004
RUN sudo apt-get update \
    && sudo apt-get install -y --no-install-recommends libatomic1 \
    && sudo rm -rf /var/lib/apt/lists/*
RUN mise use -g node@26

# add baseline CLAUDE.md
COPY --chown=ubuntu:ubuntu files/home/.claude/CLAUDE.md .claude/