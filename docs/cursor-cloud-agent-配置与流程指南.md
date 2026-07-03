# Cursor Cloud Agent 配置与流程指南

> 本文档整理自一次完整的 Cursor Cloud Agent 学习对话，**以「我当时困惑的问题」为主线**，方便日后复习，避免重复踩坑。
>
> 配套阅读：[Cloud Agent VM 底层原理指南](./cursor-cloud-agent-VM底层原理指南.md)

---

## 目录

1. [核心概念一张表](#1-核心概念一张表)
2. [Q：Cloud Agent、Workspace、Repo、VM 分别是什么？](#2-qcloud-agentworkspacerepovm-分别是什么)
3. [Q：为什么 Environment 要绑定 Git Repo？](#3-q为什么-environment-要绑定-git-repo)
4. [Q：最佳实践流程是什么？必须人工操作吗？](#4-q最佳实践流程是什么必须人工操作吗)
5. [Q：如何用 Cloud Agent 新建一个 Git Repo？](#5-q如何用-cloud-agent-新建一个-git-repo)
6. [Q：Setup Agent 是什么？和开发 Session 有何不同？](#6-qsetup-agent-是什么和开发-session-有何不同)
7. [Q：Session 和 Cloud Agent 是同一概念吗？](#7-qsession-和-cloud-agent-是同一概念吗)
8. [Q：Desktop Agent 和 Cloud Agent 的区别？](#8-qdesktop-agent-和-cloud-agent-的区别)
9. [environment.json、AGENTS.md、rules、Secrets 详解](#9-environmentjsonagentsmdrulessecrets-详解)
10. [Q：Session 启动时按什么规则执行？](#10-qsession-启动时按什么规则执行)
11. [Q：Dashboard 里的 Personal Environment 是什么？](#11-qdashboard-里的-personal-environment-是什么)
12. [Q：Update Script 是什么？有 Snapshot 还要跑吗？](#12-qupdate-script-是什么有-snapshot-还要跑吗)
13. [Q：没有 environment.json，Setup Agent 能自己探测依赖吗？](#13-q没有-environmentjsonsetup-agent-能自己探测依赖吗)
14. [本仓库的配置模板](#14-本仓库的配置模板)
15. [速查 Checklist](#15-速查-checklist)

---

## 1. 核心概念一张表

| 概念 | 一句话 | 持久吗？ |
|------|--------|---------|
| **Git Repo** | 代码的权威来源（GitHub 等） | ✅ 持久 |
| **Environment** | 为某 Repo 准备的「云端开发机配方」 | ✅ 配置持久（Dashboard + 仓库文件） |
| **Snapshot** | 配好环境后的 VM 磁盘快照，加速启动 | ✅ 持久（可过期） |
| **Cloud Agent** | 跑在云端 VM 里的自主编码代理（一种 Agent 类型） | — |
| **Session** | 一次 Cloud Agent 运行实例（一次任务） | ❌ 临时 |
| **Workspace** | Session 的 VM 内工作目录，通常是 `/workspace` | ❌ 随 VM 销毁 |
| **VM** | Session 的隔离运行环境（microVM/容器） | ❌ 临时 |

**记忆口诀：**

```
Repo = 代码在哪
Environment = 机器怎么配
Snapshot = 配好的机器拍照存档
Session = 一次具体任务
Workspace = 这次任务里操作的代码目录
```

---

## 2. Q：Cloud Agent、Workspace、Repo、VM 分别是什么？

### 我当时的困惑

- 左侧 Sessions 列表为什么在 `repositories` 目录下？
- 是不是给我分配了一台长期 VM，每个 Session 连上去？
- 还是在同一 VM 里用不同 workspace 目录隔离？

### 正确答案

**不是「一台长期 VM 多 Session 共享」，而是「每个 Session 一台临时 VM」。**

```
❌ 错误：用户 → 长期 VM → Session1(/workspace/A) + Session2(/workspace/B)

✅ 正确：每次 Session → 从 Snapshot 冷启动新 VM → /workspace clone 对应 repo → 干完销毁
```

**左侧按 Repo 分组**，是因为 Session 必须知道「为哪个代码库服务」——UI 用 repo 当文件夹。

**Workspace** 不是云端某个持久文件夹，而是 **这次 Session 的 VM 里 clone 下来的代码根目录**（常见 `/workspace`）。

### 生命周期

```
Dashboard / iOS / Linear 触发
  → Cursor 控制面调度 VM
  → clone repo → Agent 工作 → push PR
  → VM 销毁（Snapshot 配置保留）
```

---

## 3. Q：为什么 Environment 要绑定 Git Repo？

### 我当时的困惑

创建 Environment 时为什么要「绑定」一个 Git Repo？Environment 是拿 Repo 当模板复制代码吗？

### 正确答案

**Environment 绑 Repo，不是「复制代码当模板」，而是「为在这个仓库上干活准备开发机」。**

| 绑定 Repo 解决什么 | 举例 |
|-------------------|------|
| Clone 哪个代码库 | `git clone` 目标 |
| 装什么依赖 | Python vs Node |
| 读哪些 Agent 规则 | `.cursor/rules`、`AGENTS.md` |
| Secrets 作用域 | 该项目的 API Key |
| PR push 到哪里 | 对应 GitHub repo |
| Snapshot 缓存什么 | 该项目的依赖环境 |

**类比 CI/CD：** GitHub Actions workflow 必须知道为哪个 repo 服务——Environment 同理。

---

## 4. Q：最佳实践流程是什么？必须人工操作吗？

### 我总结的流程（经校正后）

```
步骤 0 [一次性]  Cursor 账号连接 GitHub，授予 repo 读写权限

步骤 1          仓库提交 Cloud 配置并 push
                .cursor/environment.json
                .cursor/Dockerfile
                scripts/cloud-install.sh
                AGENTS.md

步骤 2          （通常已包含在步骤 0）确认 GitHub 上 Cursor App 能访问该 repo

步骤 3 [推荐]   Dashboard → New Environment → 选 repo
                → Secrets 里逐条添加 K-V（不是上传 .env 文件）
                → Update Script 与 environment.json 的 install 保持一致

步骤 4 [推荐]   跑 Setup Agent → 验证环境 → Save Snapshot
                → 可选：把 Snapshot ID 写回 environment.json

步骤 5          随时开 Cloud Agent Session
                （iOS / cursor.com/agents / Desktop 选 Cloud / Linear @cursor）
```

### 哪些步骤必须人工？

| 步骤 | 能否全自动 |
|------|-----------|
| GitHub 授权 | 人做一次 |
| 创建 GitHub repo | 人或 Agent（需 `gh` + 权限） |
| Dashboard 建 Environment | 通常要人点（有 environment.json 可减轻） |
| 配 Secrets | 人在 Dashboard 填 |
| Setup Agent + Save Snapshot | 人触发 + 确认 |
| 日常开发 Session | 可高度自动化 |

**结论：Environment 是「基础设施层」，偏人工配置；Session 是「任务层」，可自动化。**

---

## 5. Q：如何用 Cloud Agent 新建一个 Git Repo？

### 我当时的困惑

如果必须先有 repo + environment 才能开 Session，那怎么「从零创建新项目」？

### 正确答案

**Cloud Agent 不能从「零 repo」启动 Session**（没有东西可以 clone）。但可以先建空 repo。

### 三条路径

| 路径 | 做法 | 推荐度 |
|------|------|--------|
| **A：先建空 repo** | `gh repo create` → 建 Environment → 开 Session 初始化代码 | ⭐⭐⭐ 最常用 |
| **B：Bootstrap 元仓库** | 专用 repo 里写 `AGENTS.md` 指导 Agent 用 `gh` 创建新 repo | ⭐⭐ 团队常用 |
| **C：在现有 repo Session 里建** | 当前 Session 挂 repo-A，Agent 创建 repo-B | ⭐ 能凑合 |

### 重要限制

- Agent **不能**在 Dashboard 为另一个 repo **创建 Environment 记录**
- Agent **可以**在新 repo 里提交 `.cursor/environment.json`（预埋配置）
- 人仍需在 Dashboard 关联新 repo，或首次启动时走 Setup

### B 和 C 的区别

机制相同，B 是「专用工具箱」，C 是「顺手借用」——都不是机制不同，而是规范程度不同。

---

## 6. Q：Setup Agent 是什么？和开发 Session 有何不同？

### 我当时的困惑

- Setup Agent 是不是也新开 VM？
- 是不是「初始化环境」完成后「搬进」正式环境？
- 能跑很多次吗？不 Save Snapshot 就白跑了？
- 只能在 Dashboard Environment 里启动吗？

### 正确答案

| | Setup Agent | 开发 Session |
|---|------------|-------------|
| **目的** | 配环境（一次性/偶尔） | 做开发任务（每次） |
| **VM 来源** | 基础镜像（尚无你的 Snapshot） | 已保存的 Snapshot |
| **产物** | Snapshot + 可选 environment.json | 代码改动 + PR |
| **能否跑多次** | ✅ 有 Setup Runs / History | 每次任务一条 |

**不是「搬进正式环境」，而是「把配好的 VM 拍成 Snapshot，以后从 Snapshot 冷启动」。**

### Save Snapshot 可选吗？

- **可选**（官方：*"you will have the option to create a snapshot"*）
- **不 Save**：VM 销毁，Snapshot 加速没了；但 Setup 日志、部分 Dashboard 配置可能还在
- **首次强烈建议 Save**

### 启动入口

| 入口 | 支持 |
|------|------|
| Dashboard → Environment → Start Setup Agent | ✅ |
| Desktop → Agents Window → Guided Setup | ✅ |
| iOS / 普通开发 Session | ❌（那是干活，不是 Setup） |

---

## 7. Q：Session 和 Cloud Agent 是同一概念吗？

**不完全是，但关系很近。**

- **Cloud Agent** = 一种 Agent **类型**（云端 VM 里跑的自主代理）
- **Session** = 一次 **运行实例**（一次任务、一段对话、一台临时 VM）

```
Cloud Agent ≈ 「外卖服务」
Session     ≈ 「你下的一单外卖」
```

---

## 8. Q：Desktop Agent 和 Cloud Agent 的区别？

### 我当时的困惑

是不是同一套机制，只是文件系统本地 vs 云端？编排放在云端还是 Desktop？断网 + 本地 LLM 能跑吗？

### 正确答案

**同一套 Agent 范式（工具、rules、AGENTS.md），两套分离的运行时。**

| 维度 | Desktop Agent | Cloud Agent |
|------|--------------|-------------|
| 编排 | Desktop App 内 | **Cursor 云端**（即使自托管 worker，agent loop 仍在云端） |
| 工具执行 | 本机 | 云端 VM |
| 需本机在线 | 是 | 否 |
| 产出 | 本地改动 | Push + PR + 录屏 |
| 环境配置 | 本机已有环境 | Environment + Snapshot |
| 断公网 | Desktop 也难完整跑 Agent | ❌ 完全不行 |
| 本地 LLM | 需隧道，且请求仍可能经 Cursor 后端 | ❌ 不能用你的本地 LLM |

**不是两套编排共用一个磁盘，而是两套运行时、共用配置语言（rules/AGENTS.md）。**

---

## 9. environment.json、AGENTS.md、rules、Secrets 详解

### environment.json 里能写什么？

| 配置什么 | 写在哪里 |
|---------|---------|
| 系统级运行时（Python/Node 版本） | `.cursor/Dockerfile` |
| 项目级依赖安装 | `install` 字段 → 脚本 |
| 串联两者 | `.cursor/environment.json` |

```json
{
  "snapshot": "snapshot-20260703-xxxx",
  "build": { "dockerfile": "Dockerfile", "context": ".." },
  "install": "bash scripts/cloud-install.sh"
}
```

**`environment.json` 不直接写「Python 3.12」**，而是通过 Dockerfile 固定版本。

### AGENTS.md 和 rules 是默认模板吗？

**没有官方默认模板文件，内容完全自定义。**

| 文件 | 格式 | 侧重 |
|------|------|------|
| `AGENTS.md` | 纯 Markdown | 怎么跑环境、测试、PR 流程（Cloud 向） |
| `.cursor/rules/*.mdc` | Markdown + YAML frontmatter | 代码规范、安全边界（本地+Cloud） |

官方只给**建议结构**（如 `AGENTS.md` 里加 `Cursor Cloud specific instructions` 一节）。

### Secrets 怎么配？

- **Dashboard → Environment → Secrets → Add**
- **K-V 键值对输入**，不是上传 `.env` 文件
- **不要** commit `.env` 到 Git
- `environment.json` **不能替代** Secrets

### 配置优先级（Environment 解析顺序）

```
1. 仓库 .cursor/environment.json     ← 最高
2. Dashboard Personal Environment
3. Dashboard Team Environment
```

---

## 10. Q：Session 启动时按什么规则执行？

### 启动流水线（固定顺序）

```
① 解析 Environment 配置
② 启动 VM（Snapshot > Dockerfile build > 默认基础镜像）
③ 执行 install（Update Script）        ← 每次必跑
④ 执行 start（如有）
⑤ 启动 terminals 后台进程（如有）
⑥ 注入 Secrets
⑦ git clone/checkout → /workspace
⑧ Agent 读 AGENTS.md、rules、hooks，开始工作
```

### environment.json 是最优先的吗？

- **在环境基础设施层面：是**（覆盖 Dashboard 配置）
- **Agent 行为**由 AGENTS.md + rules 另行约束

---

## 11. Q：Dashboard 里的 Personal Environment 是什么？

就是我截图里 `Environments` 列表中 **Scope: Personal** 的那条记录。

包含：Snapshot ID、Update Script、Secrets、Network Access、Setup History 等。

### 和 environment.json 的关系

| Dashboard 字段 | environment.json 字段 |
|---------------|----------------------|
| Update Script | `"install"` |
| Snapshot ID | `"snapshot"` |
| Dockerfile | `"build"` |

**仓库有 environment.json 时，覆盖 Dashboard 的 Personal/Team 配置。**

**Secrets 始终在 Dashboard 配，无法写入 environment.json。**

### 有 Snapshot 还要 Dockerfile 吗？

**要保留。** Snapshot 负责热启动加速；Dockerfile 负责可重建、可版本管理；Snapshot 过期时靠 Dockerfile + install 修复。

---

## 12. Q：Update Script 是什么？有 Snapshot 还要跑吗？

### 三个名字，同一个东西

```
Dashboard 里叫：Update Script
environment.json 里叫：install
官方文档有时叫：update command
```

### 有 Snapshot 还跑吗？

**要跑，每次 Session 启动都跑。**

| | Snapshot | install |
|---|----------|---------|
| 缓存什么 | 系统级状态（Python/Node 已装好） | 同步当前代码的依赖 |
| 何时变 | 重跑 Setup 并 Save 新 Snapshot | 每次 Session |

**install 必须幂等**（可重复执行、增量更新）。

### 什么放 install，什么不放？

| 适合放 install | 不适合放 install |
|---------------|-----------------|
| `pip install -r requirements.txt` | `docker compose up` |
| `npm ci` / `pnpm install` | 大型一次性编译 |

低频/耗时命令写在 `AGENTS.md`，让 Agent 按需执行。

---

## 13. Q：没有 environment.json，Setup Agent 能自己探测依赖吗？

**能。** Setup Agent 会读 `package.json`、`requirements.txt`、`Dockerfile` 等自行探测。

### 依赖更新后要重跑 Setup 吗？

| 变更类型 | 怎么办 |
|---------|--------|
| 项目依赖小改（requirements.txt、package.json） | **不用**重跑 Setup，靠每次 Session 的 install |
| 环境大改（Python 大版本、装 Docker、Snapshot 过期） | **重跑** Setup → Save 新 Snapshot |

**Setup = 配机器；install = 每次同步项目依赖。**

---

## 14. 本仓库的配置模板

PR 分支 `cloudagent/cloud-env-templates-0365` 已添加：

```
.cursor/
  Dockerfile              # Python 3.12 + Node 22
  environment.json        # 引用 Dockerfile + install 脚本
  rules/general.mdc       # 示例规范
scripts/
  cloud-install.sh        # 幂等 install
  verify-env.sh           # 启动前验证
AGENTS.md                 # Cloud Agent 操作手册
```

合并后建议：Dashboard Update Script 改为 `bash scripts/cloud-install.sh`，重跑 Setup 并 Save Snapshot。

---

## 15. 速查 Checklist

### 新项目从零到能在 iOS 上开 Agent

- [ ] GitHub 已连接 Cursor，repo 有读写权限
- [ ] 仓库有 `.cursor/environment.json` + Dockerfile + `AGENTS.md`
- [ ] 已 push 到 GitHub
- [ ] Dashboard 已建 Environment（或依赖仓库 environment.json）
- [ ] Secrets 已在 Dashboard 以 K-V 配置
- [ ] 已跑 Setup Agent 并 Save Snapshot
- [ ] （可选）Snapshot ID 写入 environment.json
- [ ] 在 cursor.com/agents 或 iOS 开 Session 测试

### 日常开发（配好一次之后）

- [ ] 本地改代码 → commit & push
- [ ] 任意设备开 Cloud Agent Session
- [ ] **不必**每次跑 Setup Agent

### 何时需要重跑 Setup？

- [ ] 改了 Dockerfile / 系统依赖大版本
- [ ] Snapshot 过期或失效
- [ ] 新增大量 Secrets 或内网访问需求

---

*文档版本：2026-07-03，基于 Cursor Cloud Agent 官方文档与一次真实 Session 环境观察整理。*
