#!/bin/sh

# 设置默认的保留天数和端口
RETENTION_DAYS=${RETENTION_DAYS:-30}
MYSQL_PORT=${MYSQL_PORT:-3306}
MAX_BACKUPS=${MAX_BACKUPS:-0} # 默认为0表示不限制文件数量
BACKUP_ALL_DATABASES=${BACKUP_ALL_DATABASES:-false} # 默认为false，不备份所有数据库
EXCLUDED_DATABASES=${EXCLUDED_DATABASES:-} # 默认为空，排除系统数据库

# 确定备份模式
if [ -n "${MYSQL_DATABASE}" ]; then
    BACKUP_MODE="single"
    echo "[${TIMESTAMP}] 检测到单数据库备份模式，数据库: ${MYSQL_DATABASE}"
elif [ "${BACKUP_ALL_DATABASES}" = "true" ]; then
    BACKUP_MODE="all"
    echo "[${TIMESTAMP}] 检测到全数据库备份模式"
else
    echo "[${TIMESTAMP}] 错误: 需要指定备份模式"
    echo "[${TIMESTAMP}] 请设置以下环境变量之一:"
    echo "[${TIMESTAMP}] - MYSQL_DATABASE (单数据库备份模式)"
    echo "[${TIMESTAMP}] - BACKUP_ALL_DATABASES=true (全数据库备份模式)"
    exit 1
fi

# 获取当前时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "[${TIMESTAMP}] ====== 开始备份任务 ======"
echo "[${TIMESTAMP}] 备份模式: ${BACKUP_MODE}"
echo "[${TIMESTAMP}] 主机: ${MYSQL_HOST}:${MYSQL_PORT}"
echo "[${TIMESTAMP}] 保留天数: ${RETENTION_DAYS}"
echo "[${TIMESTAMP}] 最大备份数: ${MAX_BACKUPS}"

# 检查必要的环境变量
if [ -z "${MYSQL_HOST}" ] || [ -z "${MYSQL_USER}" ] || [ -z "${MYSQL_PASSWORD}" ]; then
    echo "[${TIMESTAMP}] 错误: 缺少必要的环境变量"
    echo "[${TIMESTAMP}] 请确保设置了以下环境变量:"
    echo "[${TIMESTAMP}] - MYSQL_HOST"
    echo "[${TIMESTAMP}] - MYSQL_USER"
    echo "[${TIMESTAMP}] - MYSQL_PASSWORD"
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

# 获取要备份的数据库列表
DATABASES_TO_BACKUP=""
if [ "${BACKUP_MODE}" = "single" ]; then
    DATABASES_TO_BACKUP="${MYSQL_DATABASE}"
    echo "[${TIMESTAMP}] 单数据库模式，备份数据库: ${MYSQL_DATABASE}"
else
    echo "[${TIMESTAMP}] 获取所有可用数据库..."

    # 获取所有数据库并过滤系统数据库
    ALL_DATABASES=$(mysql --defaults-file="${MYSQL_CNF}" -sN -e "SHOW DATABASES")

    # 默认排除的系统数据库
    SYSTEM_DATABASES="information_schema performance_schema sys mysql"

    # 如果用户指定了排除的数据库，添加到排除列表
    if [ -n "${EXCLUDED_DATABASES}" ]; then
        SYSTEM_DATABASES="${SYSTEM_DATABASES} ${EXCLUDED_DATABASES}"
        echo "[${TIMESTAMP}] 用户指定排除的数据库: ${EXCLUDED_DATABASES}"
    fi

    # 过滤数据库列表
    DATABASES_TO_BACKUP=""
    for db in ${ALL_DATABASES}; do
        # 检查数据库是否在排除列表中
        should_exclude=false
        for excluded in ${SYSTEM_DATABASES}; do
            if [ "${db}" = "${excluded}" ]; then
                should_exclude=true
                break
            fi
        done

        if [ "${should_exclude}" = "false" ]; then
            DATABASES_TO_BACKUP="${DATABASES_TO_BACKUP} ${db}"
        fi
    done

    # 清理前后的空格
    DATABASES_TO_BACKUP=$(echo "${DATABASES_TO_BACKUP}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    echo "[${TIMESTAMP}] 将要备份的数据库:"
    for db in ${DATABASES_TO_BACKUP}; do
        echo "[${TIMESTAMP}]   - ${db}"
    done

    if [ -z "${DATABASES_TO_BACKUP}" ]; then
        echo "[${TIMESTAMP}] 错误: 没有找到可以备份的数据库"
        rm -f "${MYSQL_CNF}"
        exit 1
    fi
fi

# 执行备份
BACKUP_SUCCESS_COUNT=0
BACKUP_FAILED_COUNT=0
BACKUP_FILES=""
TOTAL_BACKUP_SIZE=0

echo "[${TIMESTAMP}] ====== 开始执行备份 ======"

for db in ${DATABASES_TO_BACKUP}; do
    echo "[${TIMESTAMP}] 开始备份数据库: ${db}"
    BACKUP_FILE="/backup/${db}_${TIMESTAMP}.sql"

    # 执行数据库备份
    if mysqldump --defaults-file="${MYSQL_CNF}" \
        --single-transaction \
        --quick \
        --set-gtid-purged=OFF \
        --triggers \
        --routines \
        --events \
        --add-drop-database \
        --add-drop-table \
        "${db}" >"${BACKUP_FILE}"; then

        # 检查备份文件大小
        if [ -s "${BACKUP_FILE}" ]; then
            FILESIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
            echo "[${TIMESTAMP}] ✓ 备份成功: ${BACKUP_FILE} (大小: ${FILESIZE})"
            BACKUP_SUCCESS_COUNT=$((BACKUP_SUCCESS_COUNT + 1))
            BACKUP_FILES="${BACKUP_FILES} ${BACKUP_FILE}"

            # 计算文件大小（以字节为单位）
            FILESIZE_BYTES=$(du -b "${BACKUP_FILE}" | cut -f1)
            TOTAL_BACKUP_SIZE=$((TOTAL_BACKUP_SIZE + FILESIZE_BYTES))
        else
            echo "[${TIMESTAMP}] ✗ 备份失败: ${BACKUP_FILE} (文件为空)"
            BACKUP_FAILED_COUNT=$((BACKUP_FAILED_COUNT + 1))
            rm -f "${BACKUP_FILE}"
        fi
    else
        echo "[${TIMESTAMP}] ✗ 备份失败: ${db}"
        BACKUP_FAILED_COUNT=$((BACKUP_FAILED_COUNT + 1))
        # 删除可能存在的不完整文件
        rm -f "${BACKUP_FILE}"
    fi

    echo "[${TIMESTAMP}] ---"
done

# 删除临时配置文件
rm -f "${MYSQL_CNF}"

# 备份结果统计
TOTAL_DB_COUNT=$(echo "${DATABASES_TO_BACKUP}" | wc -w)
TOTAL_SIZE_HUMAN=$(numfmt --to=iec ${TOTAL_BACKUP_SIZE})

echo "[${TIMESTAMP}] ====== 备份结果统计 ======"
echo "[${TIMESTAMP}] 总数据库数量: ${TOTAL_DB_COUNT}"
echo "[${TIMESTAMP}] 成功备份数量: ${BACKUP_SUCCESS_COUNT}"
echo "[${TIMESTAMP}] 失败备份数量: ${BACKUP_FAILED_COUNT}"
echo "[${TIMESTAMP}] 总备份大小: ${TOTAL_SIZE_HUMAN}"

# 检查是否至少有一个备份成功
if [ ${BACKUP_SUCCESS_COUNT} -eq 0 ]; then
    echo "[${TIMESTAMP}] 错误: 所有数据库备份都失败了"
    exit 1
fi

# 如果有失败的备份，给出警告但继续执行
if [ ${BACKUP_FAILED_COUNT} -gt 0 ]; then
    echo "[${TIMESTAMP}] 警告: 有 ${BACKUP_FAILED_COUNT} 个数据库备份失败，但继续执行清理任务"
fi

echo "[${TIMESTAMP}] ====== 备份任务部分完成，开始清理 ======"

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
