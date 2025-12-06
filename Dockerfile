# Stage 1: Builder (构建环境)
# 明确指定发行版 bookworm，避免未来 slim 变动导致不兼容
FROM python:3.10-slim-bookworm AS builder

# 1. 零网络开销安装 uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# 2. 设置环境变量优化构建行为
# UV_COMPILE_BYTECODE=1: 编译 .pyc 文件，显著提升容器启动速度
# UV_LINK_MODE=copy: 强制使用复制模式而不是硬链接，避免跨层复制文件时的潜在问题
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# 3. 利用 Docker 缓存层：先只复制依赖定义
COPY pyproject.toml uv.lock ./

# 4. 挂载构建缓存并安装依赖
# --mount=type=cache: 缓存 uv 下载的包，下次构建秒级完成
# --no-install-project: 先只装第三方库，不装当前项目（利用 Layer 缓存）
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# 5. 复制源代码
COPY . .

# 6. 安装当前项目
# 这一步非常快，因为它只会安装你的代码，不会重新下载依赖
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev


# Stage 2: Runner (生产环境)
FROM python:3.10-slim-bookworm

COPY --from=builder /bin/uv /usr/local/bin/uv

# 7. SRE 最佳实践：设置 Python 环境变量
# PYTHONUNBUFFERED=1: 保证日志直接输出到控制台，不被缓存（对 Docker logs 至关重要）
ENV PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# 8. 直接复制构建好的虚拟环境
# 相比于“安装 wheel”，直接复制文件夹速度更快，且保证环境完全一致
COPY --from=builder /app/.venv /app/.venv

# 9. 复制源代码 (如果你的项目包含非 Python 文件或需要运行时读取源码)
# 如果你的项目完全打包进库里了，这一步可以视情况省略，但通常建议保留以防万一
COPY --from=builder /app /app

# 10. 启动命令
# 由于把 .venv/bin 加入了 PATH，这里可以直接运行命令
CMD ["uv", "run",  "main.py"]