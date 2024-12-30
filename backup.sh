#!/bin/bash

# 设置默认的保留天数和端口
RETENTION_DAYS=${RETENTION_DAYS:-30}
MYSQL_PORT=${MYSQL_PORT:-3306}

# 获取当前时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/backup/${MYSQL_DATABASE}_${TIMESTAMP}.sql"

echo "[${TIMESTAMP}] 开始备份数据库 ${MYSQL_DATABASE}"

# 检查必要的环境变量
if [ -z "${MYSQL_HOST}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ] || [ -z "${MYSQL_DATABASE}" ]; then
    echo "错误: 缺少必要的环境变量"
    echo "请确保设置了以下环境变量:"
    echo "- MYSQL_HOST"
    echo "- MYSQL_USER"
    echo "- MYSQL_PASSWORD"
    echo "- MYSQL_DATABASE"
    exit 1
fi

# 测试数据库连接
if ! mysqladmin ping -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; then
    echo "[${TIMESTAMP}] 错误: 无法连接到 MySQL 服务器"
    exit 1
fi

echo "[${TIMESTAMP}] 数据库连接测试成功，开始备份..."

# 执行备份
set -o pipefail # 确保管道中的错误被捕获
mysqldump \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    "${MYSQL_DATABASE}" >"${BACKUP_FILE}"

# 检查备份结果
if [ $? -eq 0 ] && [ -s "${BACKUP_FILE}" ]; then
    echo "[${TIMESTAMP}] 数据库 ${MYSQL_DATABASE} 备份成功: ${BACKUP_FILE}"
    echo "[${TIMESTAMP}] 备份文件大小: $(du -h ${BACKUP_FILE} | cut -f1)"
else
    echo "[${TIMESTAMP}] 数据库 ${MYSQL_DATABASE} 备份失败"
    rm -f "${BACKUP_FILE}" # 删除空文件或失败的备份
    exit 1
fi

# 清理旧的备份文件（如果 RETENTION_DAYS > 0）
if [ "${RETENTION_DAYS}" -gt 0 ]; then
    echo "[${TIMESTAMP}] 清理 ${RETENTION_DAYS} 天前的备份文件"
    find /backup -name "*.sql" -type f -mtime +${RETENTION_DAYS} -delete
    echo "[${TIMESTAMP}] 旧备份文件清理完成"
else
    echo "[${TIMESTAMP}] 备份文件永久保留，跳过清理步骤"
fi
