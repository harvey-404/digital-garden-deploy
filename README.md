# Digital Garden — 统一部署

本目录提供一份 Docker Compose，同时启动 **web（Nginx）**、**server（Spring Boot）** 与 **mysql** 三个服务。

## 目录假设

以下三个目录为同级关系：

```
demo/
├── digital-garden-site-server/   # 后端仓库
├── digital-garden-site-web/      # 前端仓库
└── deploy/                       # 本目录（统一部署）
```

## 部署步骤

1. 复制环境变量并修改密钥：

   ```bash
   cp .env.example .env
   # 编辑 .env，至少修改 DB_PASSWORD、JWT_SECRET、ADMIN_PASSWORD
   ```

2. 构建并启动全部服务：

   ```bash
   docker compose --env-file .env up -d --build
   ```

3. 浏览器访问 `http://<服务器IP>`（本地为 `http://localhost`）。

   - 对外仅暴露 **80** 端口；Nginx 将 `/api/` 与 `/uploads/` 反代到内部 `server:8080`。
   - 默认管理员账号见 `.env` 中的 `ADMIN_USERNAME` / `ADMIN_PASSWORD`，**首次部署后请尽快修改**。

4. 停止服务：

   ```bash
   docker compose down
   ```

   数据保存在命名卷 `mysql_data`、`uploads_data` 中，`down` 后再 `up` 数据仍在。

## HTTPS

生产环境建议在 web 服务前增加 TLS 终止，常见做法：

- **云厂商证书**：在负载均衡或 CDN 上挂载证书，后端仍用本 compose（仅 80）。
- **Certbot + Nginx**：在 `web` 服务上增加 443 端口映射，挂载证书目录，并在 Nginx 配置中启用 `listen 443 ssl` 与 HTTP 跳转。

示例（思路，需按实际域名调整）：

```yaml
web:
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /etc/letsencrypt:/etc/letsencrypt:ro
```

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 80 端口被占用 | 本机已有 Nginx/IIS 或其他 compose；停止冲突服务或改 `ports` 映射 |
| 前端可开但 API 失败 | 确认 `web` 与 `server` 在同一 compose 网络；检查 `server` 日志 |
| 数据库连接失败 | 等待 `mysql` healthcheck 通过；检查 `.env` 中 `DB_PASSWORD` 与 compose 一致 |
| 直连后端调试跨域 | 将 `CORS_ORIGINS` 设为允许的来源；经 Nginx 同源访问时通常不触发 CORS |

## 本地开发

前后端可分别在各自仓库独立开发（前端 `npm run dev`，后端 `mvn spring-boot:run`）。本 compose 用于**联调与生产式部署**，不替代日常开发环境。
