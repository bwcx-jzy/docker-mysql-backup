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
    MYSQL_USER=root \
    MYSQL_PASSWORD=root \
    MYSQL_DATABASE=test \
    BACKUP_CRON="0 0 * * *"

# 创建定时任务
RUN echo "${BACKUP_CRON} /app/backup.sh >> /var/log/cron.log 2>&1" > /etc/crontabs/root

# 启动定时任务服务
CMD ["crond", "-f", "-l", "8"] 