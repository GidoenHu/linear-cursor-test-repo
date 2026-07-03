# linear-cursor-test-repo

Cursor Agent × Linear 集成测试仓库。

## 任务概述

本仓库用于验证 **Cursor Agent** 与 **Linear** 的完整任务闭环：在 Cursor 中讨论任务 → 创建 Linear issue → 委派给 Cursor Agent → 本地执行 → 回写 Linear 更新。

## Cursor ↔ Linear 任务流转流程

### 1. 在 Cursor 中讨论任务

用户在 Cursor 中描述需求，例如「创建一个 hello world 脚本并附任务流程说明」。Cursor 帮助梳理任务目标与完成标准。

### 2. 创建 Linear Issue

将任务同步到 Linear，创建 issue（本例为 `DEV-1`），包含：

- 任务标题与描述
- 完成标准（可运行脚本、README 文档、回写执行结果）
- 相关标签或项目归属

### 3. 委派给 Cursor Agent

在 Linear issue 中将任务委派给 Cursor Cloud Agent，或在 Cursor 中通过 issue 上下文启动 Agent。Agent 自动获取 issue 描述、评论与仓库信息。

### 4. Cursor Agent 本地执行

Agent 在配置的默认仓库中执行具体工作：

1. 创建 `hello.py`，运行时打印问候语
2. 编写本 `README.md`，记录完整流转流程
3. 运行脚本验证输出
4. 提交代码并创建 Pull Request

### 5. 回写 Linear 更新

任务完成后，Agent 在 Linear issue 中：

- 发表评论，说明执行结果与 PR 链接
- 将 issue 状态更新为 **Done**

## 运行 Hello World

```bash
python3 hello.py
```

预期输出：

```
Hello, World! Greetings from Cursor Agent × Linear integration.
```

## Cloud Agent 学习指南

基于一次完整学习对话整理的复习文档（以常见问题与困惑为主线）：

| 文档 | 内容 |
|------|------|
| [配置与流程指南](docs/cursor-cloud-agent-配置与流程指南.md) | Environment、Session、Setup Agent、Secrets、日常流程 |
| [VM 底层原理指南](docs/cursor-cloud-agent-VM底层原理指南.md) | microVM、rootfs、平台层融合、Anyrun、进程与 OS |
| [Git PR 与协作流程指南](docs/git-PR与协作流程指南.md) | push/PR/Merge 区别、自己 repo vs fork 贡献他人 |

## 文件说明

| 文件 | 说明 |
|------|------|
| `hello.py` | Hello World 脚本，验证 Agent 可正常创建并运行代码 |
| `README.md` | 本文件，描述 Cursor ↔ Linear 任务流转流程 |
| `AGENTS.md` | Cloud Agent 操作手册 |
| `.cursor/environment.json` | Cloud 环境配置（Dockerfile + install 脚本） |
