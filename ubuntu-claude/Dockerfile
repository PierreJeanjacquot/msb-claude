# dockerfile for pierreiexec/ubuntu-claude
FROM ubuntu
RUN apt update && apt install -y curl git jq nano
# add passwodless sudo for ubuntu user
RUN apt install -y sudo
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && chmod 0440 /etc/sudoers.d/ubuntu
# use non root user
USER ubuntu
WORKDIR /home/ubuntu
# setup TERM fallback to xterm-256color when connecting host uses incompatible term
RUN echo 'infocmp "$TERM" >/dev/null 2>&1 || export TERM=xterm-256color' >> ~/.bashrc
# install claude
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
# add claude-yolo alias
RUN echo 'alias claude-yolo="claude --dangerously-skip-permissions"' >> ~/.bashrc
# skip onboarding as we will use CLAUDE_CODE_OAUTH_TOKEN
RUN jq '.hasCompletedOnboarding = true' ~/.claude.json > /tmp/claude.json.tmp && mv /tmp/claude.json.tmp ~/.claude.json
# setup default status line
COPY --chown=ubuntu:ubuntu files/home/.claude/statusline-default.sh .claude/
RUN (cat ~/.claude/settings.json 2>/dev/null || echo '{}') | jq '.statusLine = {"type": "command", "command": "if [ -f $HOME/.claude/statusline.sh ]; then bash $HOME/.claude/statusline.sh; else bash $HOME/.claude/statusline-default.sh; fi"}' > /tmp/settings.json.tmp && mv /tmp/settings.json.tmp ~/.claude/settings.json
# setup skills relink from ~/.host/.agents/skills/
RUN mkdir -p .claude/hooks
COPY --chown=ubuntu:ubuntu files/home/.claude/hooks/relink-skills.sh .claude/hooks/
RUN jq '.hooks.SessionStart += [{"hooks":[{"type":"command","command":"bash \"$HOME/.claude/hooks/relink-skills.sh\"","timeout":15}]}]' ~/.claude/settings.json > /tmp/settings.json.tmp && mv /tmp/settings.json.tmp ~/.claude/settings.json
# setup git via gh
RUN sudo apt install gh -y
RUN mkdir -p .config/gh
COPY --chown=ubuntu:ubuntu files/home/.config/gh/config.yml .config/gh/
COPY --chown=ubuntu:ubuntu files/home/.config/gh/hosts.yml .config/gh/
COPY --chown=ubuntu:ubuntu files/home/.gitconfig ./
RUN mkdir -p .claude/hooks
COPY --chown=ubuntu:ubuntu files/home/.claude/hooks/setup-git-identity-from-gh.sh .claude/hooks/
RUN jq '.hooks.PreToolUse += [{"matcher":"Bash","hooks":[{"type":"command","if":"Bash(git add *)","command":"bash \"$HOME/.claude/hooks/setup-git-identity-from-gh.sh\"","timeout":30},{"type":"command","if":"Bash(git commit *)","command":"bash \"$HOME/.claude/hooks/setup-git-identity-from-gh.sh\"","timeout":30}]}]' ~/.claude/settings.json > /tmp/settings.json.tmp && mv /tmp/settings.json.tmp ~/.claude/settings.json