# AGENTS.md

本文件供 **Cursor Cloud Agent** 读取，描述如何在云端 VM 中开发、测试和提交本项目。
本地 Cursor 也会读取；更细的代码规范见 `.cursor/rules/`。

## 项目概述

Cursor × Linear 集成测试仓库。当前为轻量 Python 示例，可按需扩展 Node/前端子项目。

## Cursor Cloud specific instructions

Cloud Agent 每次从 Snapshot 启动后会自动执行 `bash scripts/cloud-install.sh`。
开始改代码前，请先验证环境：

```bash
bash scripts/verify-env.sh
```

若验证失败，停止任务并报告失败命令与完整输出，不要在不健康的环境里继续改代码。

### 运行时版本要求

| 工具 | 版本 | 配置位置 |
|------|------|----------|
| Python | 3.12+ | `.cursor/Dockerfile` |
| Node.js | 22.x | `.cursor/Dockerfile` |
| pnpm | latest | `.cursor/Dockerfile`（通过 corepack） |

系统级版本在 **Dockerfile** 中固定；项目级依赖在 **install 脚本** 中安装。

### 常用命令

| 操作 | 命令 |
|------|------|
| 验证环境 | `bash scripts/verify-env.sh` |
| 安装依赖 | `bash scripts/cloud-install.sh` |
| 运行示例 | `python3 hello.py` |
| Python 测试 | `python3 -m pytest`（添加测试后） |
| Node 脚本 | `npm run <script>` 或 `pnpm <script>`（添加 package.json 后） |

### PR 与分支

- 所有 PR 目标分支：**`main`**
- Cloud Agent 分支命名：`cloudagent/<描述>-0365`
- 提交前确认 `python3 hello.py` 可通过（若改动了相关代码）

### Secrets

敏感信息（API Key、Token 等）**不要写入仓库**。
在 Cursor Dashboard → Cloud Agents → Secrets 中配置；Agent 通过环境变量读取。

### 非显而易见事项

- `install` 脚本必须**幂等**（可重复执行），因为每次 Session 启动都会跑一遍
- 大型/低频命令（如 `docker compose up`）写在 AGENTS.md 里按需执行，不要放进 `install`
- 子目录可放置嵌套 `AGENTS.md`，处理该目录时代理会优先读取最近的文件

## 新建子项目（Python / Node）

在本仓库内添加子项目时：

1. Python：添加 `requirements.txt`，依赖由 `cloud-install.sh` 自动安装
2. Node：添加 `package.json`（可选 `pnpm-lock.yaml`），依赖由 `cloud-install.sh` 自动安装
3. 在本文档「常用命令」中补充对应的运行/测试命令

## 从本模板孵化新仓库

若任务是在 GitHub 创建**新仓库**（而非改本仓库）：

1. 使用 `gh repo create <name> --private` 创建空仓库
2. 复制以下文件到新仓库：
   - `.cursor/Dockerfile`
   - `.cursor/environment.json`
   - `scripts/cloud-install.sh`
   - `scripts/verify-env.sh`
   - `AGENTS.md`（按新项目修改）
   - `.cursor/rules/`（按需调整）
3. push 后，在 Cursor Dashboard 为新仓库创建 Environment，或依赖仓库内的 `environment.json` 自动解析
4. **无法**在 Session 中替另一个 repo 创建 Dashboard Environment，需人工在 Dashboard 关联
