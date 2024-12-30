FROM alpine:3.18

# 安装必要的软件包
RUN apk add --no-cache \
    mysql-client \
    bash \
    dcron

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

# 创建 cron 目录并设置权限
RUN mkdir -p /var/spool/cron/crontabs && \
    mkdir -p /etc/cron.d && \
    touch /var/log/cron.log && \
    chown -R root:root /var/spool/cron/crontabs && \
    chmod -R 0600 /var/spool/cron/crontabs

# 创建启动脚本
RUN echo '#!/bin/sh' > /app/entrypoint.sh && \
    echo 'echo "${BACKUP_CRON} /app/backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root' >> /app/entrypoint.sh && \
    echo 'chmod 0644 /etc/crontabs/root' >> /app/entrypoint.sh && \
    echo 'crond -f -l 8' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# 设置启动命令
CMD ["/app/entrypoint.sh"] 