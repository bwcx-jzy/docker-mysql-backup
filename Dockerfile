FROM ubuntu:22.04

# 设置非交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 安装必要的软件包
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    mysql-client-8.0 \
    cron \
    moreutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/*

# 创建备份目录
WORKDIR /app
RUN mkdir -p /backup

# 复制备份脚本
COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

# 设置环境变量默认值
ENV MYSQL_HOST=mysql \
    MYSQL_PORT=3306 \
    MYSQL_USER=root \
    MYSQL_PASSWORD=root \
    MYSQL_DATABASE=test \
    BACKUP_CRON="0 0 * * *" \
    RETENTION_DAYS=30

# 创建日志目录和文件
RUN mkdir -p /var/log && \
    touch /var/log/cron.log && \
    ln -sf /dev/stdout /var/log/cron.log

# 创建启动脚本
RUN echo '#!/bin/bash' > /app/entrypoint.sh && \
    echo 'echo "=== Starting MySQL Backup Service ===" | ts "[%Y-%m-%d %H:%M:%S]"' >> /app/entrypoint.sh && \
    echo 'echo "Setting up cron job: ${BACKUP_CRON} /app/backup.sh" | ts "[%Y-%m-%d %H:%M:%S]"' >> /app/entrypoint.sh && \
    echo 'echo "${BACKUP_CRON} /app/backup.sh 2>&1 | ts \"[%Y-%m-%d %H:%M:%S]\"" > /etc/cron.d/mysql-backup' >> /app/entrypoint.sh && \
    echo 'chmod 0644 /etc/cron.d/mysql-backup' >> /app/entrypoint.sh && \
    echo 'crontab /etc/cron.d/mysql-backup' >> /app/entrypoint.sh && \
    echo 'exec cron -f' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# 设置启动命令
CMD ["/app/entrypoint.sh"] 