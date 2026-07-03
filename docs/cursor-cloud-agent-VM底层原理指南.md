# Cursor Cloud Agent VM 底层原理指南

> 本文档整理自一次深入学习对话的后半段，**以「我对 VM / 镜像 / OS 的困惑」为主线**，解释 Cloud Agent 的运行时架构。
>
> 配套阅读：[配置与流程指南](./cursor-cloud-agent-配置与流程指南.md)

---

## 目录

1. [先建立正确心智模型](#1-先建立正确心智模型)
2. [Q：Cloud VM 里只有 workspace 吗？](#2-qcloud-vm-里只有-workspace-吗)
3. [Q：用 K8s 类比对吗？Cursor 基于 K8s 吗？](#3-q用-k8s-类比对吗cursor-基于-k8s-吗)
4. [Q：Setup Agent 是能创建 Pod 的特殊 Pod 吗？](#4-qsetup-agent-是能创建-pod-的特殊-pod-吗)
5. [Q：我的 Dockerfile 写的是 FROM ubuntu，runtime 从哪来？](#5-q我的-dockerfile-写的是-from-ubunturuntime-从哪来)
6. [Q：为什么要「装 Docker」？VM 本身不是容器吗？](#6-q为什么要装-dockervm-本身不是容器吗)
7. [Q：平台层 + Dockerfile 是怎么融合的？](#7-q平台层--dockerfile-是怎么融合的)
8. [Q：所有进程还是 OS 在管吗？](#8-q所有进程还是-os-在管吗)
9. [Q：FROM ubuntu 是「唯一的 OS」吗？](#9-qfrom-ubuntu-是唯一的-os-吗)
10. [Q：是 OS 安装前写盘，还是 docker run 后再装平台程序？](#10-q是-os-安装前写盘还是-docker-run-后再装平台程序)
11. [三层嵌套：不要和项目 docker compose 混淆](#11-三层嵌套不要和项目-docker-compose-混淆)
12. [从构建到 Session 的完整时间线](#12-从构建到-session-的完整时间线)
13. [已知 vs 未公开](#13-已知-vs-未公开)
14. [术语速查](#14-术语速查)

---

## 1. 先建立正确心智模型

**一句话：**

> Cloud VM = **一个 microVM + 一个 Linux 内核 + 一块 rootfs（系统盘）**；平台和你的 Dockerfile 都只是往这块盘里放了不同来源的文件；所有进程由**这一个内核**统一管理。

**不是：**

- ❌ 一台长期 VM 多 Session 共享
- ❌ 外层 Cursor 容器套内层开发容器（默认情况）
- ❌ 两个操作系统并行
- ❌ 标准 Kubernetes Pod（但可用类似概念理解）

---

## 2. Q：Cloud VM 里只有 workspace 吗？

### 我当时的困惑

VM 是不是只作为 workspace？还是包含 Cursor Agent 软件系统？

### 正确答案：Worker 运行时 + workspace

在一次真实 Session VM 中观察到：

| 组件 | 作用 |
|------|------|
| **`pod-daemon`**（PID 1） | 容器/microVM init，生命周期管理 |
| **`exec-daemon`**（Node.js） | **本地 Agent 运行时**：终端、文件、浏览器、录屏、MCP、tmux |
| **`cursor-server`** | 类似 VS Code Server |
| **xfce + VNC + noVNC** | Computer Use（GUI 操作） |
| **`cursorsandbox`** | 命令沙箱 |
| **`/workspace`** | clone 的代码 |

`exec-daemon` 连接 `https://api2.cursor.sh` 收发工具调用指令。

### 分工

```
Cursor 云端（大脑）          Cloud VM（手脚）
  LLM 推理、Agent 编排  ←→   exec-daemon 执行工具
                              cursor-server + 桌面
                              /workspace 代码
```

**VM ≠ 纯 workspace，而是「Cursor Worker 运行时 + 你的开发环境 + 代码目录」。**

---

## 3. Q：用 K8s 类比对吗？Cursor 基于 K8s 吗？

### 我当时的困惑

前面用 K8s 类比，那 Cursor 真是 K8s 吗？

### 正确答案：类比帮助理解，实现不是标准 K8s

根据公开工程报道（Pragmatic Engineer 等）和论坛 infra 讨论：

| 组件 | 技术 |
|------|------|
| **编排器** | **Anyrun**（Cursor 自研，Rust；公司 Anysphere 的梗） |
| **计算** | AWS EC2 |
| **隔离** | **AWS Firecracker**（microVM） |
| **基础设施** | Terraform |

论坛里 Cursor 员工会说 *"Pod exists but exec-daemon is unreachable"*——**「Pod」是内部术语**，不等于标准 K8s Pod。

### 概念映射（仅供理解）

| K8s 概念 | Cursor 近似 |
|---------|------------|
| Control Plane | Anyrun + Cursor API（api2.cursor.sh） |
| Pod | Firecracker microVM（内部称 pod） |
| Container Image | 平台镜像 + Dockerfile 层 + Snapshot |
| Job | Setup Agent Session |

### Enterprise 自托管

可在**自己的 Kubernetes** 上跑 worker，但 **Agent loop 仍在 Cursor 云端**。

---

## 4. Q：Setup Agent 是能创建 Pod 的特殊 Pod 吗？

### 我当时的困惑

Setup Agent 是不是跑在「能 new pod」的 Pod 里？它怎么被创建？

### 正确答案

**不是。** Setup Agent 没有「在集群里创建 Pod」的权限。

```
❌ Setup Pod（有 create pod 权限）→ 创建 Development Pod → Save Snapshot

✅ 用户点 Dashboard
     → Cursor 控制面（Anyrun）调度一个新 Pod/microVM
     → 里面跑 Setup 任务
     → 用户 Save Snapshot → 控制面冻结磁盘状态
     → Pod 销毁
   以后开发 Session：控制面从 Snapshot 拉起新 Pod
```

**创建和调度都在 Cursor 控制面**，不在 VM 内部。

---

## 5. Q：我的 Dockerfile 写的是 FROM ubuntu，runtime 从哪来？

### 我当时的困惑

Dockerfile 的 `FROM ubuntu:24.04` 不是 Cursor 镜像，控制面会改 Dockerfile 吗？

### 正确答案

**不会改你仓库里的 `FROM` 行。**

平台 runtime（`exec-daemon`、`pod-daemon` 等）通过 **构建时合并** 和/或 **启动时注入** 进入最终环境，不是靠你在 Dockerfile 里安装。

```
最终 VM
  = Cursor 平台层（runtime，平台提供）
  + 你的 Environment 层（Dockerfile / Snapshot）
  + 每次 install 增量
  + /workspace 代码
```

### 证据

- VM 里 `exec_daemon_version` 指向 **S3** 上的包 → 可能启动时注入/更新
- 你的 Dockerfile 只有 `ubuntu + python + node` → 不可能单独产生 exec-daemon
- 社区 Dockerfile 也用 `FROM node:22-bookworm-slim` 等普通镜像

**你的 Dockerfile 只管「额外装什么」；平台管「这台机器能当 Agent Worker」。**

---

## 6. Q：为什么要「装 Docker」？VM 本身不是容器吗？

### 我当时的困惑

VM 底层是 Docker 吗？默认不装 Docker？有 Dockerfile 是不是 VM 上再套容器？

### 正确答案：三层别混

**观察到的 VM：**

- 文件系统：`docker overlay2`（说明 rootfs 与容器镜像技术相关）
- `docker` 命令：**默认不存在**（`command not found`）

### 两个「Dockerfile」

| 文件 | 作用 |
|------|------|
| **`.cursor/Dockerfile`** | 定义 **Agent 开发机镜像** 怎么构建（加 Python/Node） |
| **项目 `Dockerfile` / `docker-compose.yml`** | 定义 **你的应用** 怎么容器化 |

### 层级

```
层级 1：Agent Worker 环境（一个 Linux rootfs）
         平台 runtime + 你的 apt 包
         进程直接跑，不再套「开发容器」

层级 2：/workspace（代码目录）

层级 3：（可选）docker compose up postgres
         ← 只有项目需要时，Docker-in-VM
```

官方：*"Docker runs inside another container layer"* —— 指 **DinD 场景**，不是默认融合方式。

---

## 7. Q：平台层 + Dockerfile 是怎么融合的？

### 我当时的困惑

以为是「外层 Agent + 内层 Docker 容器」双层结构，或 microVM 天生双层。

### 正确答案：一块 rootfs，多种来源的文件

```
❌ 两个 OS 并行
❌ 外层容器套内层容器（默认）

✅ 一个内核 + 一块系统盘（rootfs）
   /exec-daemon/     ← 平台
   /usr/bin/python3  ← 你的 Dockerfile
   /workspace/       ← Session clone
   全部是同一文件系统里的路径
```

### 融合可能机制（官方未完全公开）

| 机制 | 说明 |
|------|------|
| **构建时层合并** | BuildKit 把平台层和你的 `RUN` 层叠成一张 rootfs 镜像 |
| **启动时注入** | VM 起来后从 S3 解压/更新 exec-daemon |
| **Snapshot** | 冻结当时整块磁盘状态 |

**microVM（Firecracker）只负责隔离启动，不负责「怎么叠层」——叠层是 Anyrun 在构建/启动环境时做的。**

---

## 8. Q：所有进程还是 OS 在管吗？

### 我当时的担心

是不是不再是操作系统统一管理进程了？

### 正确答案：始终是同一个内核

```
一个 Linux 内核
  PID 1: pod-daemon
    ├── exec-daemon
    ├── cursor-server
    ├── xfce / VNC
    ├── python3
    └── bash / npm ...

同一棵进程树，同一个调度器。
```

平台和 Dockerfile 装的软件，只是 **磁盘上不同路径的文件**，启动后都是普通 Linux 进程。

**类比本机：** IT 预装的软件和你 `apt install` 的软件，都是 macOS/Linux 同一个内核在管。

---

## 9. Q：FROM ubuntu 是「唯一的 OS」吗？

### 我当时的理解

`FROM ubuntu` = VM 里唯一的 OS 镜像？

### 精确说法

**`FROM ubuntu` = rootfs（用户态根目录）模板，不是带内核的完整物理机 OS。**

| 组件 | 来源 |
|------|------|
| **Linux 内核** | 平台为 microVM 提供（与 `FROM` 分开） |
| **rootfs（/bin, /usr, /etc...）** | 主要来自 `FROM ubuntu` + 你的 `RUN` |
| **平台文件（/exec-daemon）** | 平台构建/注入 |

```
microVM = 虚拟硬件 + 内核 + rootfs 块设备
                ↑           ↑
            平台给      FROM ubuntu + RUN + 平台层
```

经典 Docker 容器：**镜像无内核，共用宿主机内核。**  
Firecracker microVM：**有自己的内核**，所以比纯容器更像「一台小虚拟机」。

---

## 10. Q：是 OS 安装前写盘，还是 docker run 后再装平台程序？

### 我的两种猜测

- **A：** OS 安装前先在磁盘写程序，装完 OS 后并列
- **B：** `docker run` 成功后再装平台程序

### 正确答案：更像是「预制系统盘镜像」

**不是 A：** 没有「空盘 → 跑 Ubuntu 安装向导 → 重启」这种流程。

**B 部分对：** 可能有启动后注入（exec-daemon 从 S3），但大块内容在 **启动前的镜像/Snapshot** 里。

**最接近的模型：**

```
【构建时】在 Cursor 构建机上
  ubuntu 层 + 你的 RUN 层 +（可能）平台层
  → 合并成一块 rootfs 镜像
  → Save Snapshot = 这块盘拍照

【启动时】
  Firecracker 挂载内核 + rootfs
  pod-daemon 起来 →（可能）patch exec-daemon
  install 脚本 → git clone
```

**不是更神秘的扇区手写，而是：镜像层 + OverlayFS + 块设备 Snapshot + Firecracker。**

---

## 11. 三层嵌套：不要和项目 docker compose 混淆

```
层级 0：Cursor 控制面（Anyrun + api2.cursor.sh）

层级 1：Agent Worker（一个 microVM，一套 rootfs）
         ← 平台和 Dockerfile 融合在这里

层级 2：/workspace（git clone，普通目录）

层级 3：（可选）docker compose（项目自己的 Postgres 等）
         ← 这才是「VM 里再跑 Docker」
```

---

## 12. 从构建到 Session 的完整时间线

```
【一次性 / 偶尔】
  写 .cursor/Dockerfile + environment.json
  Dashboard Setup Agent → Save Snapshot

【每次 Session】
  ① Anyrun 从 Snapshot（或 Dockerfile build / 默认镜像）启动 microVM
  ② 内核启动，PID 1 = pod-daemon
  ③ exec-daemon 连接 api2.cursor.sh
  ④ 跑 install 脚本（幂等增量）
  ⑤ git clone → /workspace
  ⑥ 云端 Agent loop 通过 exec-daemon 执行工具
  ⑦ 完成 → push PR → VM 销毁

【Snapshot 不变】
  日常小改依赖只靠 install，不重跑 Setup
```

---

## 13. 已知 vs 未公开

### 有证据确认

- VM 内有 `pod-daemon`、`exec-daemon`、`cursor-server`、桌面环境
- `exec-daemon` 连 `api2.cursor.sh`，trace 含 `anyrun_cluster`
- 文件系统为 overlay（容器镜像技术）
- 编排器为 Anyrun + Firecracker（公开报道）
- Agent loop 在 Cursor 云端
- 用户 Dockerfile 使用普通 `FROM ubuntu` / `FROM node` 是正常做法

### 官方未完全公开

- 平台层与 Dockerfile 层 **精确合并算法**（构建合并 vs 启动注入的比例）
- 每次 Session 是否都走 Firecracker（还是部分场景用纯容器）
- 内部 Checkpoint 与 Dashboard Snapshot 的技术关系细节

**复习时记住效果即可：** 一台 Linux、一个内核、一块盘，平台和你的依赖都在同一 rootfs 里。

---

## 14. 术语速查

| 术语 | 含义 |
|------|------|
| **rootfs** | 根文件系统，目录树 `/bin` `/usr` `/etc` 等 |
| **OCI 镜像层** | 每次 `RUN` 产生一层文件差异，BuildKit 缓存 |
| **OverlayFS** | 多层合并成一棵可见目录树 |
| **Firecracker** | AWS 的轻量 microVM 技术 |
| **Anyrun** | Cursor 自研编排器（Rust） |
| **exec-daemon** | VM 内 Agent 工具执行运行时 |
| **pod-daemon** | VM init 进程（PID 1） |
| **Snapshot** | 整块环境磁盘的状态快照 |
| **DinD** | Docker-in-Docker，VM 内再跑 docker compose 时用 |

---

## 复习用「一句话版」

1. **每个 Session = 一台临时 microVM**，不是长期共享的电脑。
2. **VM 里有完整 Worker 栈**，不只是 `/workspace`。
3. **大脑在云端（api2.cursor.sh），手脚在 VM（exec-daemon）。**
4. **平台和 Dockerfile 进同一块 rootfs**，不是两个 OS。
5. **所有进程仍由一个 Linux 内核管理。**
6. **`FROM ubuntu` 是 rootfs 模板**，不是传统意义的「装一套 OS」。
7. **编排是 Anyrun + Firecracker**，不是标准 K8s，但可用 K8s 概念帮助理解。
8. **项目 docker compose 是可选的第三层**，别和平台融合混为一谈。

---

*文档版本：2026-07-03，基于 Cursor 官方文档、公开工程报道与一次真实 Cloud Agent Session 的进程/文件系统观察整理。*
