# notify-telegram-cli（个人 fork）

让 AI agent 通过 Telegram Bot 主动给你推送消息。

本仓库是 [ascorblack/notify-telegram-cli](https://github.com/ascorblack/notify-telegram-cli) 的 fork，在此之上加了一层「装到 DSH 里、中文可触发」的配置。上游的 CLI 代码未作任何改动。

上游是 `upstream`，本 fork 是 `origin`：

```bash
git fetch upstream
git diff upstream/main          # 看本 fork 相对上游的全部改动
git log --oneline upstream/main..main
```

## 本 fork 相对上游改了什么

只有四处，其中三处是新增文件：

| 文件 | 改动 |
|---|---|
| `skills/notify-telegram/SKILL.md` | description 加了中文触发词，正文逐字未动 |
| `install.sh` | 新增。幂等安装 launcher + skill 软链 |
| `setup-wizard.sh` | 新增。引导式配置向导 |
| `SETUP.md` | 新增。本文件 |

## 装了什么，装在哪

| 位置 | 内容 |
|---|---|
| 本仓库根目录 | 就是 CLI 本身（`notify_cli.py`） |
| `~/.local/bin/notify` | launcher，指向本仓库的 `notify_cli.py` |
| `skills/notify-telegram/SKILL.md` | 本仓库内的 skill |
| `~/.agents/skills/notify-telegram` | 软链到上一行，DSH 的 user skill root，所有项目可用 |
| `~/.config/notify-telegram-cli/config.json` | token / chat_id / 代理，权限 600 |

launcher 里写的是本仓库的绝对路径，所以 `git pull` 之后行为立即更新，不用重装。

## 安装 / 重装

```bash
./install.sh              # 幂等，可反复运行
./install.sh --update     # 顺带 git pull 更新本仓库
./install.sh --dry-run    # 只报告要做什么，不改任何东西
```

它做五件事：确认 CLI 在位 → 校验 skill 源码在 → 生成 launcher → 建 skill 软链 → 保证配置目录存在且为 700。

只负责「装」，凭据归 `setup-wizard.sh`。两者可以分开重跑。

skill 软链是幂等的：指向正确就跳过；指向别处就替换；若占位的是真实目录（例如上游安装脚本 `cp` 进来的副本），会先备份成 `.bak-<时间戳>` 再建软链。

## 首次配置

```bash
./setup-wizard.sh
```

向导带你走四步：确认代理 → 在 BotFather 建 bot 拿 token → 发一条消息自动捕获 chat_id → 写配置并发测试消息。

token 用隐藏输入读取，直接落进 600 权限的配置文件，**不经过对话记录**。

## 换机 / 重建

顺序是 `install.sh` → `setup-wizard.sh`。

```bash
git clone https://github.com/Etsuya233/notify-telegram-cli.git ~/programming/tg-notification
cd ~/programming/tg-notification
./install.sh          # 装 launcher + skill 软链
./setup-wizard.sh     # 重建凭据
```

凭据在 `~/.config/notify-telegram-cli/config.json`，不在仓库里，所以新机器必须重跑向导。

工作区位置变了也没关系：`./install.sh` 会把 launcher 里的绝对路径按新位置重写，再重跑一次即可。

## 怎么用

装好之后直接对我说：

- 「跑完了发消息告诉我」
- 「这个要跑很久，完成后 Telegram 通知我」
- 「把失败的测试摘要发我」

`notify-telegram` skill 会自动触发。手动调用也可以：

```bash
notify "部署完成"
notify --title "夜间报告" "$(printf '| 套件 | 通过 |\n|---|---|\n| api | 120 |')"
notify --photo /tmp/screenshot.png --caption "修好后的界面"
notify --file /tmp/logs.zip --title "事故日志"
```

默认走 Telegram Rich Messages（`sendRichMessage`），Markdown 表格、公式、标题都会被原生渲染，不用转义。服务端不支持时自动降级成纯文本。

## 排查

```bash
notify --doctor          # 检查配置、代理、launcher、skill、API 连通性
notify --dry-run "hi"    # 只构造请求，不发送
```

doctor 不会打印 token，只回报 `reachable as @yourbot`。

## 注意

- 上游仓库**没有 LICENSE 文件**。个人自用没问题，若要再分发需先找作者确认。
- 上游默认代理写死 `http://127.0.0.1:10809`。本机实际走 `http://172.26.176.1:7890`，向导已经把它写进配置，因此不再依赖环境变量。
- skill 用软链指向本仓库，因此 `~/.agents/skills/notify-telegram` 不受上游重装影响。正文与上游逐字一致，唯一改动是 description。
- 上游 description 是纯英文，而 DSH **只按 name 和 description 路由**（`whenToUse` 不参与）。中文提问触发不了它，所以加了 `通知我 / 发消息给我 / 告我一声 / 跑完叫我 / ping 我`。上限 500 字符，当前 246。
- 配置改了之后不需要重启 DSH。skill 正文每次加载都会重读，catalog 变更由 watcher 推送。
- 换 bot 或换收件会话，重跑 `./setup-wizard.sh` 即可。向导会先把旧配置备份成 `config.json.bak-<时间戳>`。
