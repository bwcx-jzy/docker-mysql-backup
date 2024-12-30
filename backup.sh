#!/bin/bash

# 设置默认的保留天数和端口
RETENTION_DAYS=${RETENTION_DAYS:-30}
MYSQL_PORT=${MYSQL_PORT:-3306}

# 获取当前时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/backup/${MYSQL_DATABASE}_${TIMESTAMP}.sql"

echo "[${TIMESTAMP}] 开始备份数据库 ${MYSQL_DATABASE}"

# 执行备份
mysqldump -h ${MYSQL_HOST} \
    -P ${MYSQL_PORT} \
    -u ${MYSQL_USER} \
    -p${MYSQL_PASSWORD} \
    --databases ${MYSQL_DATABASE} >${BACKUP_FILE}

# 检查备份结果
if [ $? -eq 0 ]; then
    echo "[${TIMESTAMP}] 数据库 ${MYSQL_DATABASE} 备份成功: ${BACKUP_FILE}"
else
    echo "[${TIMESTAMP}] 数据库 ${MYSQL_DATABASE} 备份失败"
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
