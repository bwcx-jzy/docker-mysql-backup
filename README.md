# MySQL 数据库备份方案

使用 Docker 容器实现 MySQL 数据库的定时备份功能。本项目提供了一个简单可靠的方案来自动备份 MySQL 数据库，并支持自定义备份频率。

## 项目文件

项目包含以下文件：
- `Dockerfile`: 用于构建备份服务镜像
- `backup.sh`: 数据库备份脚本
- `README.md`: 使用说明文档

## 功能特点

- 自动定时备份 MySQL 数据库
- 备份文件保存为 SQL 格式，使用时间戳命名
- 支持自定义备份时间间隔
- 支持多架构部署（AMD64/ARM64）
- 支持自定义备份文件保留天数
- 支持自定义 MySQL 端口
- 备份过程日志记录

## 使用方法

### 1. 构建镜像

#### 使用预构建镜像
可以直接使用 Docker Hub 上的预构建镜像：
```bash
docker pull bwcxjzy/docker-mysql-backup:latest
```

#### 单架构构建
在项目目录下执行以下命令构建镜像：
```bash
docker build -t bwcxjzy/docker-mysql-backup .
```

#### 多架构构建
使用 Docker Buildx 构建多架构镜像：
```bash
# 创建并使用 buildx 构建器
docker buildx create --use

# 构建并推送多架构镜像
docker buildx build --platform linux/amd64,linux/arm64 \
  -t bwcxjzy/docker-mysql-backup:latest \
  --push .
```

### 2. 运行容器

使用以下命令运行备份容器：
```bash
docker run -d \
  --name mysql-backup \
  -e MYSQL_HOST=mysql \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_DATABASE=your_database \
  -e BACKUP_CRON="0 0 * * *" \
  -e RETENTION_DAYS=30 \
  -v /path/to/backup:/backup \
  bwcxjzy/docker-mysql-backup:latest
```

### 环境变量说明

- `MYSQL_HOST`: MySQL 容器名称或地址
- `MYSQL_PORT`: MySQL 端口号（可选，默认为 3306）
- `MYSQL_USER`: MySQL 用户名
- `MYSQL_PASSWORD`: MySQL 密码
- `MYSQL_DATABASE`: 要备份的数据库名
- `BACKUP_CRON`: 备份频率（Cron 表达式格式）
- `RETENTION_DAYS`: 备份文件保留天数（可选，默认30天，设置为0表示永久保留）
- `SET_GTID_PURGED`: 控制 `mysqldump --set-gtid-purged` 参数（可选，默认为 `AUTO`，可设置为 `ON`/`OFF`）

### BACKUP_CRON 示例

- `0 0 * * *` - 每天凌晨 00:00 执行备份
- `0 */12 * * *` - 每12小时执行一次备份
- `0 */6 * * *` - 每6小时执行一次备份
- `0 0 */2 * *` - 每隔两天的凌晨执行备份
- `0 0 * * 0` - 每周日凌晨执行备份

### 查看备份日志

可以通过以下命令查看备份日志：
```bash
docker logs mysql-backup
```

### 备份文件

- 备份文件保存在挂载的 `/backup` 目录中
- 文件名格式：`数据库名_年月日_时分秒.sql`
- 例如：`mydb_20240315_000000.sql`

## 注意事项

1. 确保备份容器与 MySQL 容器在同一个 Docker 网络中
2. 确保挂载的备份目录有足够的存储空间
3. 备份文件会自动保存在挂载的 `/backup` 目录中
4. 如果设置了 RETENTION_DAYS，超过指定天数的备份文件会被自动删除
5. 首次运行时请确保提供的 MySQL 连接信息正确
6. 多架构构建需要 Docker Buildx 支持

## 示例场景

假设你有一个正在运行的 MySQL 容器，配置如下：
```bash
# MySQL 容器运行示例
docker run -d \
  --name mysql \
  -e MYSQL_ROOT_PASSWORD=123456 \
  -p 3307:3306 \
  mysql:8.0
```

对应的备份容器配置（永久保留备份文件）：
```bash
# 备份容器运行示例
docker run -d \
  --name mysql-backup \
  -e MYSQL_HOST=mysql \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=123456 \
  -e MYSQL_DATABASE=mydb \
  -e BACKUP_CRON="0 0 * * *" \
  -e RETENTION_DAYS=0 \
  -v /data/mysql-backup:/backup \
  bwcxjzy/docker-mysql-backup:latest
```

## 故障排查

1. 如果备份失败，检查：
   - MySQL 连接信息是否正确
   - 网络连接是否正常
   - 备份目录权限是否正确
   - 磁盘空间是否充足

2. 查看备份日志：
```bash
docker logs mysql-backup
```

3. 进入容器排查：
```bash
docker exec -it mysql-backup sh
```

## 支持的架构

本项目支持以下 CPU 架构：
- linux/amd64 (x86_64)
- linux/arm64 (aarch64)

使用 buildx 构建的镜像会自动选择适合当前平台的版本。
