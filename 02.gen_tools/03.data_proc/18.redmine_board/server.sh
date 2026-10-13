#!/bin/bash
# RK Issue Board - 代理服务器管理脚本
# 用法: ./server.sh start|stop|restart|status

DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="$DIR/server.py"
PID_FILE="$DIR/.server.pid"
PORT=9100

is_running() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    kill -0 "$PID" 2>/dev/null && return 0
    rm -f "$PID_FILE"
  fi
  # 也检查端口是否被占用
  lsof -ti:$PORT -sTCP:LISTEN >/dev/null 2>&1 && return 0
  return 1
}

do_start() {
  if is_running; then
    echo "Server already running on port $PORT"
    return 0
  fi
  nohup python3 "$SERVER" -p "$PORT" > "$DIR/server.log" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1
  if is_running; then
    echo "Server started on port $PORT (PID $(cat "$PID_FILE"))"
    echo "Open http://127.0.0.1:$PORT/ in browser"
  else
    echo "Failed to start server, check $DIR/server.log"
    rm -f "$PID_FILE"
    return 1
  fi
}

do_stop() {
  if ! is_running; then
    echo "Server is not running"
    rm -f "$PID_FILE"
    return 0
  fi
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    kill "$PID" 2>/dev/null
  fi
  # 兜底：按端口杀
  lsof -ti:$PORT -sTCP:LISTEN | xargs kill 2>/dev/null
  sleep 1
  rm -f "$PID_FILE"
  echo "Server stopped"
}

do_status() {
  if is_running; then
    PID=$(cat "$PID_FILE" 2>/dev/null || echo "unknown")
    echo "Server is running (port $PORT, PID $PID)"
  else
    echo "Server is not running"
  fi
}

do_open() {
  do_start
  open "http://127.0.0.1:$PORT/"
}

case "$1" in
  start)   do_start ;;
  stop)    do_stop ;;
  restart) do_stop; do_start ;;
  status)  do_status ;;
  open)    do_open ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|open}"
    echo ""
    echo "  start   - 后台启动代理服务器"
    echo "  stop    - 停止代理服务器"
    echo "  restart - 重启代理服务器"
    echo "  status  - 查看服务器状态"
    echo "  open    - 启动服务器并打开浏览器"
    ;;
esac
