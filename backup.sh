#!/bin/sh

# 设置默认的保留天数和端口
RETENTION_DAYS=${RETENTION_DAYS:-30}
MYSQL_PORT=${MYSQL_PORT:-3306}
MAX_BACKUPS=${MAX_BACKUPS:-0} # 默认为0表示不限制文件数量

# 获取当前时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/backup/${MYSQL_DATABASE}_${TIMESTAMP}.sql"

echo "[${TIMESTAMP}] ====== 开始备份任务 ======"
echo "[${TIMESTAMP}] 数据库: ${MYSQL_DATABASE}"
echo "[${TIMESTAMP}] 主机: ${MYSQL_HOST}:${MYSQL_PORT}"
echo "[${TIMESTAMP}] 保留天数: ${RETENTION_DAYS}"
echo "[${TIMESTAMP}] 最大备份数: ${MAX_BACKUPS}"

# 检查必要的环境变量
if [ -z "${MYSQL_HOST}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ] || [ -z "${MYSQL_DATABASE}" ]; then
    echo "[${TIMESTAMP}] 错误: 缺少必要的环境变量"
    echo "[${TIMESTAMP}] 请确保设置了以下环境变量:"
    echo "[${TIMESTAMP}] - MYSQL_HOST"
    echo "[${TIMESTAMP}] - MYSQL_USER"
    echo "[${TIMESTAMP}] - MYSQL_PASSWORD"
    echo "[${TIMESTAMP}] - MYSQL_DATABASE"
    exit 1
fi

# 创建临时的 MySQL 配置文件
MYSQL_CNF=$(mktemp)
cat >"${MYSQL_CNF}" <<EOF
[client]
host=${MYSQL_HOST}
port=${MYSQL_PORT}
user=${MYSQL_USER}
password=${MYSQL_PASSWORD}
EOF

# 测试数据库连接
echo "[${TIMESTAMP}] 测试数据库连接..."
if ! mysqladmin --defaults-file="${MYSQL_CNF}" ping --connect-timeout=10 --silent; then
    echo "[${TIMESTAMP}] 错误: 无法连接到 MySQL 服务器"
    rm -f "${MYSQL_CNF}"
    exit 1
fi

echo "[${TIMESTAMP}] 数据库连接成功，开始备份..."

# 执行备份
mysqldump --defaults-file="${MYSQL_CNF}" \
    --single-transaction \
    --quick \
    --set-gtid-purged=OFF \
    --triggers \
    --routines \
    --events \
    --add-drop-database \
    --add-drop-table \
    "${MYSQL_DATABASE}" >"${BACKUP_FILE}"

# 删除临时配置文件
rm -f "${MYSQL_CNF}"

# 检查备份结果和文件大小
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -eq 0 ] && [ -s "${BACKUP_FILE}" ]; then
    FILESIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo "[${TIMESTAMP}] 备份成功: ${BACKUP_FILE}"
    echo "[${TIMESTAMP}] 文件大小: ${FILESIZE}"
else
    echo "[${TIMESTAMP}] 备份失败"
    rm -f "${BACKUP_FILE}" # 删除空文件或失败的备份
    exit 1
fi

echo "[${TIMESTAMP}] ====== 开始清理过期备份 ======"

# 按天数清理旧的备份文件
if [ "${RETENTION_DAYS}" -gt 0 ]; then
    echo "[${TIMESTAMP}] 清理 ${RETENTION_DAYS} 天前的备份文件..."
    OLD_FILES=$(find /backup -name "*.sql" -type f -mtime +${RETENTION_DAYS})
    if [ -n "${OLD_FILES}" ]; then
        echo "[${TIMESTAMP}] 删除以下过期文件:"
        echo "${OLD_FILES}"
        find /backup -name "*.sql" -type f -mtime +${RETENTION_DAYS} -delete
        echo "[${TIMESTAMP}] 按天数清理完成"
    else
        echo "[${TIMESTAMP}] 没有过期的备份文件需要清理"
    fi
else
    echo "[${TIMESTAMP}] 未设置备份保留天数，跳过按天数清理"
fi

# 按数量清理旧的备份文件
if [ "${MAX_BACKUPS}" -gt 0 ]; then
    echo "[${TIMESTAMP}] 检查备份数量限制: ${MAX_BACKUPS}"
    # 获取当前备份文件数量
    CURRENT_COUNT=$(find /backup -name "*.sql" -type f | wc -l)
    if [ "${CURRENT_COUNT}" -gt "${MAX_BACKUPS}" ]; then
        # 计算需要删除的文件数量
        DELETE_COUNT=$((CURRENT_COUNT - MAX_BACKUPS))
        echo "[${TIMESTAMP}] 当前备份数量: ${CURRENT_COUNT}, 需要删除: ${DELETE_COUNT}"
        # 获取要删除的文件列表
        DELETE_FILES=$(find /backup -name "*.sql" -type f -printf '%T+ %p\n' | sort | head -n ${DELETE_COUNT} | cut -d' ' -f2-)
        echo "[${TIMESTAMP}] 删除以下文件:"
        echo "${DELETE_FILES}"
        echo "${DELETE_FILES}" | xargs rm -f
        echo "[${TIMESTAMP}] 按数量清理完成"
    else
        echo "[${TIMESTAMP}] 当前备份数量(${CURRENT_COUNT})未超过限制"
    fi
else
    echo "[${TIMESTAMP}] 未设置备份数量限制，跳过按数量清理"
fi

echo "[${TIMESTAMP}] ====== 备份任务完成 ======"
