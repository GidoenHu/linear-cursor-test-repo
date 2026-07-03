# Git Pull Request 与协作流程指南

> 本文档整理自 Cursor Cloud Agent 学习对话中关于 **PR、分支、fork** 的问答，方便日后复习。
>
> 相关文档：[Cloud Agent 配置与流程指南](./cursor-cloud-agent-配置与流程指南.md)

---

## 目录

1. [PR 到底是什么？](#1-pr-到底是什么)
2. [Q：push、开 PR、Merge 有什么区别？](#2-qpush开-prmerge-有什么区别)
3. [Q：自己的仓库还要开 PR 吗？](#3-q自己的仓库还要开-pr-吗)
4. [Q：给别人仓库提 PR 的完整流程](#4-q给别人仓库提-pr-的完整流程)
5. [Q：能直接 clone 原主 repo 吗？](#5-q能直接-clone-原主-repo-吗)
6. [三种场景对比表](#6-三种场景对比表)
7. [Merge 的三种方式](#7-merge-的三种方式)
8. [与 Cloud Agent 的关系](#8-与-cloud-agent-的关系)
9. [常用命令速查](#9-常用命令速查)

---

## 1. PR 到底是什么？

**Pull Request（拉取请求）= 一条「请把某分支的改动合并进目标分支」的提案。**

重要区分：

- **PR 不是「把分支加入仓库」** —— 分支在 `git push` 时就已经在远程仓库里了
- **PR 不是自动 merge** —— 需要 Review 后手动（或配置自动）点 Merge
- **Merge 之后**，目标分支（通常是 `main`）才包含你的改动

```
push 分支  →  远程仓库里已有这条分支
开 PR      →  申请：feature 分支 → main
Merge PR   →  main 更新，包含你的 commit
```

---

## 2. Q：push、开 PR、Merge 有什么区别？

| 步骤 | 命令/操作 | 发生了什么 |
|------|----------|-----------|
| **push 分支** | `git push -u origin feature/xxx` | 远程仓库**多出一条分支**，`main` 还没变 |
| **开 PR** | GitHub → Create Pull Request | 创建合并**申请** + 代码对比界面 |
| **Merge PR** | GitHub PR 页 → Merge | 分支上的 commit **进入 main** |

### 时间线示意

```
main:        A --- B --- C ------------------- M   ← Merge 之后
                              \               /
feature:                       D --- E --- F
                               ↑
                          push 时分支已在远程
                               ↑
                          PR = 「请把 D-E-F 合进 main」
```

### 我当时的困惑

> PR 是把分支加入仓库吗？还是直接 merge 到 main？

**答案：**

- 分支加入远程仓库 → **push 时**已完成
- 改动进入 `main` → **Merge PR 时**才完成
- 开 PR 本身 **不会**自动改 `main`

---

## 3. Q：自己的仓库还要开 PR 吗？

### 可以这么理解

在自己仓库里：

```
push 分支 → 开 PR → Merge
```

相当于 **在 GitHub 上完成合并**，不必本地 `git checkout main && git merge`。

### 为什么还要 PR？（即使只有自己）

| 好处 | 说明 |
|------|------|
| **代码审查界面** | 逐文件看 diff |
| **CI 检查** | 合并前跑 GitHub Actions |
| **记录** | 保留讨论、Review 历史 |
| **Cloud Agent 习惯** | Agent 默认产出 PR，而不是直接推 main |

### 有权限时的其他做法（不推荐日常用）

```bash
# 本地直接合进 main 再 push（跳过 PR）
git checkout main
git merge feature/xxx
git push origin main
```

能这样做，但失去 PR 的审查和 CI 闸门；**个人项目也建议保留 PR 流程**。

---

## 4. Q：给别人仓库提 PR 的完整流程

### 标准流程（你没有原仓库写权限时）

这是你理解的 **fork 流程**，完全正确：

```
① Fork
   GitHub 打开 原主/原仓库
   → 点右上角 Fork
   → 得到 你的用户名/原仓库名

② Clone 你的 fork（不是原主的）
   git clone https://github.com/你的用户名/原仓库名.git
   cd 原仓库名

③ 添加 upstream 远程（推荐，便于同步原仓库更新）
   git remote add upstream https://github.com/原主/原仓库名.git

④ 同步原仓库 main（开始新功能前）
   git fetch upstream
   git checkout main
   git merge upstream/main    # 或 git rebase upstream/main

⑤ 新建功能分支
   git checkout -b feature/my-fix

⑥ 修改、commit
   git add .
   git commit -m "描述改动"

⑦ Push 到你的 fork
   git push -u origin feature/my-fix

⑧ 在 GitHub 开 PR
   源（head）：你的用户名/原仓库名 的 feature/my-fix
   目标（base）：原主/原仓库名 的 main

⑨ 等原主 Review → Merge
   改动进入原主的 main
   你的 fork 可以保留，以后继续贡献
```

### PR 页面要选对方向

```
┌─────────────────────────────────────────┐
  base:  原主/repo  ←  main        （合到哪里去）
  compare: 你/repo  ←  feature/xxx （你的改动从哪来）
└─────────────────────────────────────────┘
```

---

## 5. Q：能直接 clone 原主 repo 吗？

### 没有写权限时

```bash
git clone https://github.com/原主/repo.git   # ✅ 可以读
git push origin feature/xxx                   # ❌ 403，没有权限
```

**必须 fork**，push 到自己的 fork，再 PR 到原主。

### 你是 Collaborator（协作者）时

```bash
git clone https://github.com/原主/repo.git   # ✅
git push origin feature/xxx                   # ✅ 可推到原仓库新分支
# 开 PR：原仓库内 分支 → main（不用 fork）
```

和在自己仓库里干活几乎一样。

---

## 6. 三种场景对比表

| 场景 | 要不要 fork | Clone 谁 | Push 到哪 | PR 怎么开 |
|------|------------|---------|----------|----------|
| **自己的 repo** | ❌ | 自己的 repo | 同仓库新分支 | 同仓库：分支 → `main` |
| **别人 repo，无写权限** | ✅ | **自己的 fork** | **自己的 fork** | fork 分支 → 原 repo `main` |
| **别人 repo，有写权限** | ❌ | 原 repo | 原 repo 新分支 | 同仓库：分支 → `main` |

### 流程图（给别人贡献，无写权限）

```
原主/owner/repo (main)
        ↑
        │ PR（Merge 请求）
        │
你/fork/repo (feature 分支)
        ↑
        │ git push
        │
    本地 clone
```

---

## 7. Merge 的三种方式

在 GitHub PR 页点 Merge 时通常有三种：

| 方式 | 效果 | 适用 |
|------|------|------|
| **Create a merge commit** | `main` 上多一个合并 commit，保留分支完整历史 | 想保留每次 commit |
| **Squash and merge** | 分支上多个 commit **压成 main 上一个** | 个人/小团队常用，历史更干净 |
| **Rebase and merge** | 分支 commit 接到 `main` 末尾，线性历史 | 喜欢直线型 git log |

选哪种看团队规范；**不影响 PR 的本质**，只影响 `main` 上的 commit 历史形状。

---

## 8. 与 Cloud Agent 的关系

| 场景 | Cloud Agent 行为 |
|------|-----------------|
| **你有读写权限的 repo** | Agent push 分支 → 开 PR（你现在的工作流） |
| **组织 repo** | 需 Cursor 已授权 + 你有写权限 |
| **只读的开源 repo** | Agent **不能**直接 push 到原主；需 fork 到你账号，让 Agent 在 fork 上工作 |

### Agent 能自动 Merge PR 吗？

| 能力 | 默认 |
|------|------|
| 创建 PR | ✅ |
| 修自己 PR 的 CI 失败 | ✅（一定条件下） |
| **自动 Merge 进 main** | ❌ 需你在 GitHub 点 Merge，或开 Auto-merge + CI 通过 |

---

## 9. 常用命令速查

### 自己的仓库

```bash
git checkout -b feature/xxx
# ... 改代码 ...
git add .
git commit -m "描述"
git push -u origin feature/xxx
# → GitHub 开 PR → Merge
```

### Fork 贡献他人仓库

```bash
# 一次性
git clone https://github.com/你/fork-repo.git
cd fork-repo
git remote add upstream https://github.com/原主/repo.git

# 每次贡献前
git fetch upstream
git checkout main && git merge upstream/main

# 开发
git checkout -b feature/xxx
# ... 改代码 ...
git commit -m "描述"
git push -u origin feature/xxx
# → GitHub：fork 的 feature/xxx → 原主 main
```

### 同步 fork（原主 main 已有更新）

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main          # 更新你的 fork 的 main
```

---

## 复习用一句话

| 概念 | 一句话 |
|------|--------|
| **push** | 把分支放到**你有写权限的远程** |
| **PR** | 申请把分支改动**合并进目标分支** |
| **Merge** | 真正让改动**进入 main** |
| **fork** | 无写权限时，先复制一份到你账号下再 push |
| **自己 repo** | 不用 fork，PR 是同仓库内的合并流程 |

---

*文档版本：2026-07-03，整理自 Cursor Cloud Agent 学习对话中的 Git/PR 问答。*
