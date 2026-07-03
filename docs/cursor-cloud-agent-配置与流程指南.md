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
14. [Q：commit/PR 与 VM 销毁的关系](#14-qcommitpr-与-vm-销毁的关系)
15. [Q：如何主动 Stop / 结束 Session？](#15-q如何主动-stop--结束-session)
16. [Q：有 Snapshot 时还会读 environment.json 吗？](#16-q有-snapshot-时还会读-environmentjson-吗)
17. [Q：超时后 VM 销毁，再回复会怎样？](#17-q超时后-vm-销毁再回复会怎样)
18. [Q：Prompt Cache 时效是什么？](#18-qprompt-cache-时效是什么)
19. [Q：Cursor 有「5 小时 N 条」滚动窗口吗？](#19-qcursor-有5-小时-n-条滚动窗口吗)
20. [本仓库的配置模板](#20-本仓库的配置模板)
21. [速查 Checklist](#21-速查-checklist)

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

## 14. Q：commit/PR 与 VM 销毁的关系

### 我当时的困惑

- 自动 commit 是不是和 VM 资源释放绑定？
- 超时不回复时，Agent 会不会在销毁前自动 commit 并开 PR？

### 正确答案：间接相关，不是销毁前自动保存

```
自动 commit + push  →  改动进 GitHub  →  VM 销毁也不丢
不 commit             →  改动只在 VM 磁盘  →  VM 销毁就丢
```

| 机制 | 真正目的 |
|------|---------|
| **边做边 commit/push** | 交付 PR、团队可见、**防止 VM 销毁后丢失未推送改动** |
| **VM 销毁** | Session/Run 结束或超时后回收 microVM |
| **销毁前自动 commit？** | ❌ **没有可靠、公开的「销毁前保底提交」机制** |

### 各种状态下 VM 销毁后会怎样？

| 状态 | VM 销毁后 |
|------|----------|
| 已 **push** 到 GitHub | ✅ 安全，PR 也在 |
| 只 **commit** 未 push | ❌ 随 VM 丢失 |
| **改了文件但未 commit** | ❌ 丢失 |

**不能指望**「用户超时不回复 → Cursor 自动帮 commit/开 PR」。

### Cloud Agent 的 commit / PR 工作流

```
一个任务 → 一个 feature 分支 → 一个 PR
                ↓
        多次 commit 累积在同一 PR 里
```

| 场景 | 是否自动 commit |
|------|----------------|
| 编码/配置类任务 | ✅ 有实质改动就 commit + push（不必每轮等你开口） |
| 纯问答、无文件改动 | ❌ 不 commit |
| 你明确说「先别提交」 | 等你 |

### 计费补充

Cursor 论坛说明：Cloud Agent **主要按 token/API 用量计费**，不是按 VM 占多久。commit 策略的核心是 **别把改动只留在临时 VM**，不是为了省 VM 租金。

---

## 15. Q：如何主动 Stop / 结束 Session？

### 我当时的困惑

找不到 Stop 按钮；长期挂着会不会一直占资源？

### 常见入口

| 位置 | 操作 |
|------|------|
| **Agent 对话页输入框旁** | ⏹ Stop（Agent **正在跑**时最明显） |
| **[cursor.com/agents](https://cursor.com/agents)** | 进入 Session → Stop |
| **Cursor Desktop / iOS** | Cloud Agent 窗口 → Stop |
| **API** | `POST /v1/agents/{id}/runs/{runId}/cancel` |
| **归档（API）** | `POST /v1/agents/{id}/archive` |

### 为什么有时看不到 Stop？

**① Agent 在等你回复（Run 可能已结束）**

```
Agent 正在跑（写代码、跑命令）  →  Stop 明显
Agent 已答完，等你说话        →  可能无 Stop，像普通聊天
```

**② 看错了页面**

- **Environment 页**（Dashboard → Environments）= 配机器、Setup Agent
- **Session 页**（cursor.com/agents）= 具体任务对话 → **Stop 在这里**

**③ UI 不同步（已知问题）**

VM 可能已结束但界面仍显示 Running。可刷新 [cursor.com/agents](https://cursor.com/agents) 或 Desktop `Developer: Reload Window`。

### Run / Session / VM 三层

```
Agent（Session）  = 对话容器，可多次 run
  └── Run         = 一轮干活（RUNNING → FINISHED / CANCELLED / EXPIRED）
        └── VM    = Run 活跃时存在；结束后回收
```

- **Stop / Cancel**：停当前 **Run**
- **你不回消息**：Run 可能已 FINISHED，VM 在宽限期后回收，不等于必须再点 Stop

### 长期不回复会怎样？

- VM **不会无限期保留**；任务完成或空闲过久会回收
- 自托管 worker 参考：`--idle-release-timeout`（如 600 秒）= Session 结束后多留一会儿等 follow-up，**不是**销毁前自动 commit
- 已 **push** 的改动在 GitHub 上安全；未 push 的会丢

---

## 16. Q：有 Snapshot 时还会读 environment.json 吗？

### 我当时的困惑

有 Snapshot 时，新开 Session 是不是就不读 `environment.json` 来构建了？`snapshot` 字段干什么用？Setup Agent 会用吗？

### 正确答案：仍然读，而且优先级最高

**有 Snapshot 不等于跳过 `environment.json`。** 每次 Session 启动都会 **解析** 当前分支 commit 里的 `environment.json`（若存在），它是 Environment 配置的 **第一优先级**。

区别只是 **「从哪启动 VM」** 和 **「是否重建 Dockerfile」**：

```
有 environment.json 时，每次 Session：

① 读取 environment.json（含 snapshot、build、install）
② 若有 snapshot 字段且 Snapshot 可用 → 从 Snapshot 恢复 VM（快）
   若 Snapshot 失效 → 回退 Dockerfile build 或默认基础镜像
③ 仍执行 install 字段里的命令
④ checkout 代码 → Agent 开始
```

| 字段 | 有 Snapshot 时还用吗？ | 作用 |
|------|---------------------|------|
| `"snapshot"` | ✅ 用于步骤②，决定从哪张快照启动 | 指向 Dashboard 保存的快照 ID |
| `"install"` | ✅ 每次仍执行 | 增量同步项目依赖 |
| `"build"` | ⚠️ 平时不重建；Snapshot 失效时作 **后备** | 可重建环境的 Dockerfile |
| `"start"` / `"terminals"` | ✅ 仍读取 | 启动后台服务 |

### `snapshot` 字段是干嘛的？

**把 Dashboard 里 Save 的快照 ID 写进仓库，方便版本管理和团队共享。**

官方示例：

```json
{
  "snapshot": "snapshot-20260212-00000000-0000-0000-0000-000000000000",
  "install": "bash scripts/cloud-install.sh"
}
```

| 存在位置 | 作用 |
|---------|------|
| **Dashboard Environment 详情页** | UI 里看到、管理 Snapshot |
| **environment.json 的 `snapshot`** | 同一 ID 写进 Git，团队拉代码即知道用哪个快照 |

两者指向 **同一个 Snapshot**；仓库有 `environment.json` 时 **以仓库为准**（覆盖 Dashboard Personal/Team 配置）。

### Setup Agent 和 `snapshot` 字段的关系

**Setup Agent 负责「制造」Snapshot；`snapshot` 字段负责「引用」Snapshot。**

```
Setup Agent 跑完
    → 你在 Dashboard 点 Save Snapshot
    → 得到 Snapshot ID（如 snapshot-20260703-xxxx）
    → （可选）复制到 environment.json 的 "snapshot" 字段并 commit

之后每次开发 Session：
    → 读 environment.json
    → 用其中的 snapshot ID 启动（而不是重新 docker build）
```

Setup Agent **运行过程中**通常还没有 `snapshot` 字段（第一次配环境）；Save 之后才产生 ID。所以：

- Setup 时：多从 **基础镜像 / Dockerfile** 冷启动
- 日常 Session：多从 **snapshot 字段** 热启动

### 常见误解纠正

| 误解 | 实际 |
|------|------|
| 有 Snapshot 就不读 environment.json | ❌ 仍读，且优先级最高 |
| snapshot 字段给 Setup Agent 用 | ❌ Setup **产出** Snapshot；字段给 **后续 Session 引用** |
| 有 Snapshot 就不跑 install | ❌ install **每次仍跑** |
| 有 Snapshot 就不需要 Dockerfile | ❌ Dockerfile 是 Snapshot 失效时的后备 |

---

## 17. Q：超时后 VM 销毁，再回复会怎样？

> 以下与下一节（Prompt Cache）、§19（用量限制）是**三个独立机制**，只是学习时连续想到，一并记录。

### 我当时的困惑

Cloud Agent 回复超时、VM 销毁后，若我继续在同一 Session 发消息，对话还在吗？未提交的改动呢？

### 三件事分开看

| 机制 | 是什么 | 超时/销毁后 |
|------|--------|------------|
| **VM** | 临时开发机 | 销毁；未 push 的改动丢失 |
| **对话 transcript** | Cursor 云端存的聊天记录 | 默认长期保留 |
| **Prompt Cache** | 模型侧计费缓存（见 §18） | 与 VM 无关 |

### 你在同一 Session 再发消息时

```
之前：Run 结束 / EXPIRED → VM 销毁
        ↓
你在同一 Agent Session 再发一条
        ↓
Cursor 从云端加载对话历史（transcript）✅
        ↓
从 Environment Snapshot 拉起新 VM（不是同一台机器）
        ↓
重新 checkout、跑 install
        ↓
Agent 带着历史上下文继续
```

| 内容 | 还在吗？ |
|------|---------|
| 聊天记录（transcript） | ✅ 通常还在 |
| 已 push 到 GitHub 的代码 | ✅ |
| VM 里未 commit / 未 push 的改动 | ❌ |
| 同一台 VM | ❌ 是新 VM |

官方说明（Security 文档概括）：

- **Conversation history**：默认**无限期保留**（团队可配 90 天策略）
- **Environment snapshots**：**90 天无活动**删除；每次从 Snapshot 启动会续期 90 天

Cloud Agent API：follow-up run 使用 agent 的 **current conversation and workspace state**——workspace 指当次 checkout 的状态，不是「永远保留同一台 VM 的磁盘」。

---

## 18. Q：Prompt Cache 时效是什么？

### 我当时的困惑

听说对话有「上下文缓存」，用户一段时间不回复就会释放，之后下一轮全部按未命中计费——这是真的吗？多久？

### 正确答案：真的，但是模型侧的 Prompt Cache，不是 VM

Cursor 员工 Colin（论坛）说明要点：

- 缓存由**底层模型提供商**（Anthropic 等）决定，本地 / Cloud / 自托管 **行为一致**
- 对 Claude（Anthropic）：Cursor 使用约 **5 分钟**默认缓存窗口，**滑动续期**
- 每次 cache hit 会**刷新**窗口；活跃对话可一直 hit
- 若 **空闲超过约 5 分钟**，下一轮会 **full re-seed**（重新写 cache，计费更贵）

### 和你听说的说法的对照

| 说法 | 判断 |
|------|------|
| 一段时间不回复，缓存释放 | ✅ 对 **Prompt Cache**（约 5 分钟无新请求） |
| 之后全部当未命中、重新计费 | ✅ **计费上**相当于重新 seed 前缀 |
| 对话内容 Agent 忘了 | ❌ 历史仍会发给模型，只是可能没有 cache read 低价 |
| 和 VM 销毁是一回事 | ❌ **完全独立** |

### 时效参考

| 类型 | 时效 |
|------|------|
| **Prompt Cache（Anthropic，经 Cursor）** | 约 **5 分钟滑动**；有 hit 就续 |
| **1 小时 TTL** | Anthropic API 支持；Cursor 默认是否启用需以当时产品为准 |
| **对话 transcript** | Cursor 云端默认长期保留（不是 Prompt Cache） |
| **Environment Snapshot** | 90 天无活动删除 |

### 即使不到 5 分钟也可能 cache 失效

- 中途换模型
- 编辑早期消息
- 切换 tools / rules
- 前缀 token 不完全一致

**复习要点：** Prompt Cache 管的是 **「同样前缀能不能便宜读」**；transcript 管的是 **「聊天记录还在不在」**。

---

## 19. Q：Cursor 有「5 小时 N 条」滚动窗口吗？

### 我当时的困惑

Cursor 高级 LLM API 是否有 5 小时 N 条的滚动窗口？

### 不要和 Claude Pro 的「5 小时消息额度」混为一谈

| 产品 | 常见机制 |
|------|---------|
| **Claude Pro（网页/App）** | 约 5 小时滚动消息额度（Anthropic 订阅，非 Cursor 专属） |
| **Cursor Pro** | 月度用量池 + Agent **速率限制** |
| **Cloud Agent** | 按 **API token 定价**，有 spend limit |

### Cursor 更接近什么？

（细节以 Dashboard → Usage 为准，政策可能更新）

| 限制 | 说明 |
|------|------|
| **月度 credit 池** | 手动选高级模型时消耗（如 Pro 含一定美元额度） |
| **Burst rate limit** | 短时间高强度用 Agent 会触顶 |
| **Local rate limit** | 稳态限制，文档称 **每几小时** refill |
| **Auto 模式** | 与手动选模型的额度规则不同 |

**不是**单一的「5 小时 N 次请求」规则，而是：

```
月度额度（credit）+ 几小时刷新的速率限制（rate limit）
```

Cloud Agent API 里 Run 状态有 `EXPIRED` 等，指 **单次 Run 过期**，不是「5 小时 N 条」订阅窗口。

### 计费提醒

论坛说明：Cloud Agent **主要按 token 计费**，不完全是「VM 占多久收多久」。但仍建议任务完成后结束 Session，不要长期挂着。

---

## 20. 本仓库的配置模板

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

## 21. 速查 Checklist

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

*文档版本：2026-07-03（修订：超时续聊、Prompt Cache、用量限制、commit/VM、Stop Session、snapshot 与 environment.json），基于 Cursor Cloud Agent 官方文档、论坛说明与一次真实 Session 环境观察整理。*
