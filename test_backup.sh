#!/bin/bash

# 测试 backup.sh 脚本的新功能

echo "====== 测试 backup.sh 脚本 ======"
echo "当前工作目录: $(pwd)"
echo "脚本位置: /home/user/ai-code/docker-mysql-backup/backup.sh"

# 测试1: 缺少环境变量的情况
echo -e "\n=== 测试1: 缺少必要环境变量 ==="
export MYSQL_HOST=""
export MYSQL_USER=""
export MYSQL_PASSWORD=""
export MYSQL_DATABASE=""
export BACKUP_ALL_DATABASES="false"

timeout 5 /home/user/ai-code/docker-mysql-backup/backup.sh
echo "退出代码: $?"

# 测试2: 单数据库备份模式
echo -e "\n=== 测试2: 单数据库备份模式 ==="
export MYSQL_HOST="localhost"
export MYSQL_USER="testuser"
export MYSQL_PASSWORD="testpass"
export MYSQL_DATABASE="testdb"
unset BACKUP_ALL_DATABASES

timeout 10 /home/user/ai-code/docker-mysql-backup/backup.sh
echo "退出代码: $?"

# 测试3: 全数据库备份模式
echo -e "\n=== 测试3: 全数据库备份模式 ==="
export MYSQL_HOST="localhost"
export MYSQL_USER="testuser"
export MYSQL_PASSWORD="testpass"
export BACKUP_ALL_DATABASES="true"
unset MYSQL_DATABASE
export EXCLUDED_DATABASES="test_db1,test_db2"

timeout 10 /home/user/ai-code/docker-mysql-backup/backup.sh
echo "退出代码: $?"

# 测试4: 错误配置（同时设置单数据库和全数据库）
echo -e "\n=== 测试4: 错误配置 ==="
export MYSQL_HOST="localhost"
export MYSQL_USER="testuser"
export MYSQL_PASSWORD="testpass"
export MYSQL_DATABASE="testdb"
export BACKUP_ALL_DATABASES="true"

timeout 5 /home/user/ai-code/docker-mysql-backup/backup.sh
echo "退出代码: $?"

echo -e "\n====== 测试完成 ======"