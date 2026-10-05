#!/usr/bin/env bash
#
# 幂等安装：把 launcher 和 skill 软链装到位。可以反复运行。
#
# 本仓库就是 CLI 本身（fork 自 ascorblack/notify-telegram-cli），所以不需要 clone 任何东西。
# 只管「装」，不管「凭据」。token / chat_id 由 ./setup-wizard.sh 负责。
#
# 用法：
#   ./install.sh              装
#   ./install.sh --update       顺带 git pull 更新本仓库
#   ./install.sh --dry-run    只报告将要做什么，不改任何东西
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_PY="$REPO_DIR/notify_cli.py"
SKILL_SRC="$REPO_DIR/skills/notify-telegram"
BIN_DIR="${NOTIFY_INSTALL_BIN_DIR:-$HOME/.local/bin}"
SKILL_ROOT="${LEGACY_AGENTS_SKILL_DIR:-$HOME/.agents/skills}"
SKILL_LINK="$SKILL_ROOT/notify-telegram"
CONFIG_DIR="${NOTIFY_INSTALL_CONFIG_DIR:-$HOME/.config/notify-telegram-cli}"

UPDATE=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --update)  UPDATE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
    *) echo "install: 未知参数 $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
skip() { printf '  \033[2m·\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; }
die()  { printf 'install: 错误: %s\n' "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then printf '  \033[2m[dry-run]\033[0m %s\n' "$*"; else "$@"; fi
}

# ── 1. CLI 源码（本仓库自身） ──────────────────────────────────────────────
log ""
log "1/5  CLI 源码"
if [[ -f "$CLI_PY" ]]; then
  ok "$CLI_PY"
  if (( UPDATE )); then
    if [[ -d "$REPO_DIR/.git" ]]; then
      run git -C "$REPO_DIR" pull --ff-only
      (( DRY_RUN )) || ok "已更新到 $(git -C "$REPO_DIR" log --oneline -1 2>/dev/null || echo '未知版本')"
    else
      warn "$REPO_DIR 不是 git 仓库，跳过 --update"
    fi
  else
    skip "如需更新本仓库，加 --update"
  fi
else
  die "找不到 $CLI_PY —— 仓库不完整"
fi

# ── 2. skill 源码 ──────────────────────────────────────────────────────────
log ""
log "2/5  skill 源码"
if [[ -f "$SKILL_SRC/SKILL.md" ]]; then
  ok "$SKILL_SRC/SKILL.md"
else
  die "找不到 $SKILL_SRC/SKILL.md —— 仓库不完整"
fi

# ── 3. launcher ────────────────────────────────────────────────────────────
log ""
log "3/5  launcher → $BIN_DIR/notify"
if [[ -x "$REPO_DIR/scripts/install-notify.sh" ]]; then
  if (( DRY_RUN )); then
    run env NOTIFY_INSTALL_REPO_DIR="$REPO_DIR" NOTIFY_INSTALL_BIN_DIR="$BIN_DIR" \
        "$REPO_DIR/scripts/install-notify.sh"
  else
    # 上游脚本自带提示，真跑时压掉，免得和本脚本的输出混在一起
    env NOTIFY_INSTALL_REPO_DIR="$REPO_DIR" NOTIFY_INSTALL_BIN_DIR="$BIN_DIR" \
        "$REPO_DIR/scripts/install-notify.sh" >/dev/null
    ok "已生成 launcher（指向 $CLI_PY）"
  fi
else
  die "找不到 $REPO_DIR/scripts/install-notify.sh"
fi

# ── 4. skill 软链 ──────────────────────────────────────────────────────────
log ""
log "4/5  skill 软链 → $SKILL_LINK"
if [[ -L "$SKILL_LINK" ]]; then
  current="$(readlink "$SKILL_LINK")"
  if [[ "$current" == "$SKILL_SRC" ]]; then
    skip "已指向正确位置"
  else
    warn "原指向 $current，改为 $SKILL_SRC"
    run rm -f "$SKILL_LINK"
    run ln -s "$SKILL_SRC" "$SKILL_LINK"
  fi
elif [[ -e "$SKILL_LINK" ]]; then
  # 真实目录（例如上游安装脚本 cp 进来的副本）。备份，不静默删除。
  backup="$SKILL_LINK.bak-$(date +%Y%m%d-%H%M%S)"
  warn "已存在真实目录（可能是上游 cp 的副本），备份为 $(basename "$backup")"
  run mv "$SKILL_LINK" "$backup"
  run ln -s "$SKILL_SRC" "$SKILL_LINK"
else
  run mkdir -p "$SKILL_ROOT"
  run ln -s "$SKILL_SRC" "$SKILL_LINK"
  (( DRY_RUN )) || ok "已创建"
fi

# ── 5. 配置目录 ────────────────────────────────────────────────────────────
log ""
log "5/5  配置目录 → $CONFIG_DIR"
if [[ -d "$CONFIG_DIR" ]]; then
  mode="$(stat -c '%a' "$CONFIG_DIR")"
  if [[ "$mode" == "700" ]]; then
    skip "已存在，权限 700"
  else
    warn "权限为 $mode，收紧到 700"
    run chmod 700 "$CONFIG_DIR"
  fi
else
  run mkdir -p "$CONFIG_DIR"
  run chmod 700 "$CONFIG_DIR"
  (( DRY_RUN )) || ok "已创建（权限 700）"
fi
[[ -f "$CONFIG_DIR/config.json" ]] || skip "尚无 config.json —— 下一步的向导会写"

# ── 收尾 ───────────────────────────────────────────────────────────────────
log ""
if (( DRY_RUN )); then
  log "dry-run 结束，未做任何改动。"
  exit 0
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR 不在 PATH 里。加上：export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

log "安装完成。"
log ""
if [[ -f "$CONFIG_DIR/config.json" ]]; then
  log "凭据已存在。验证：  notify --doctor"
  log "要换 bot：          ./setup-wizard.sh"
else
  log "下一步配置凭据：    ./setup-wizard.sh"
fi
