#!/bin/bash
#
# start-flutter-web.sh — 启动 Flutter Web Server (生产模式)
#
# 用法:
#   ./start-flutter-web.sh
#
# 功能:
#   1. 进入 code/charging-station-client 目录
#   2. 启动 flutter run -d web-server (监听 0.0.0.0:8081)
#   3. 记录 PID 到 /tmp/flutter-web.pid
#   4. 执行健康检查 (60 秒超时)

set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../code/charging-station-client" && pwd)"
PID_FILE="/tmp/flutter-web.pid"
HOST="0.0.0.0"
PORT="8081"
TIMEOUT=60

# 清理旧进程
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[INFO] 停止旧进程 (PID: $OLD_PID)"
        kill "$OLD_PID" 2>/dev/null || true
        sleep 1
    fi
    rm -f "$PID_FILE"
fi

cd "$APP_DIR"

echo "[INFO] 启动 Flutter Web Server: $HOST:$PORT"
echo "[INFO] 工作目录: $APP_DIR"

# 启动 Flutter web server 在后台
# 使用 web-server 设备启动，指定 host 和 port
flutter run -d web-server \
    --web-hostname="$HOST" \
    --web-port="$PORT" \
    --release \
    > >(tee /tmp/flutter-web.log) 2>&1 &
FLUTTER_PID=$!

echo "$FLUTTER_PID" > "$PID_FILE"
echo "[INFO] Flutter PID: $FLUTTER_PID (已写入 $PID_FILE)"

# 健康检查 — 等待服务器就绪
echo "[INFO] 健康检查 ($TIMEOUT 秒超时)..."
HEALTH_URL="http://localhost:$PORT"
ELAPSED=0
INTERVAL=2

while [ $ELAPSED -lt $TIMEOUT ]; do
    # 先检查进程是否存活
    if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
        echo "[ERROR] Flutter 进程已退出，启动失败。"
        echo "[ERROR] 日志:"
        tail -20 /tmp/flutter-web.log
        rm -f "$PID_FILE"
        exit 1
    fi

    # 尝试 HTTP 请求
    if HTTP_RESULT=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null); then
        if [ "$HTTP_RESULT" = "200" ]; then
            PAGE_CONTENT=$(curl -s "$HEALTH_URL" 2>/dev/null)
            if echo "$PAGE_CONTENT" | grep -qi "flutter"; then
                echo "[OK] 健康检查通过 — 返回 200，页面包含 Flutter 框架。"
                echo "[OK] Web 服务运行于 http://$HOST:$PORT"
                exit 0
            else
                echo "[WARN] 服务已响应，但页面未检测到 Flutter 框架。继续等待..."
            fi
        fi
    fi

    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))
done

# 超时处理
echo "[ERROR] 健康检查超时 ($TIMEOUT 秒)，服务器未就绪。"
echo "[ERROR] 日志:"
tail -30 /tmp/flutter-web.log
rm -f "$PID_FILE"
exit 1