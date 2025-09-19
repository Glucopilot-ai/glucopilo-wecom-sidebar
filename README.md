# WeCom Sidebar Integration

企业微信侧边栏应用集成 - Flutter Web + Python FastAPI 解决方案

## 项目概述

WeCom-Sidebar 是一个为企业微信开发的侧边栏应用，采用现代化的技术栈构建：

- **前端**: Flutter Web (编译为 JavaScript)
- **后端**: Python FastAPI 
- **部署**: Nginx 反向代理 + SSL
- **集成**: 企业微信 JavaScript SDK

## 技术架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   企业微信客户端   │    │   Nginx (SSL)    │    │  Python FastAPI │
│                │    │                  │    │                │
│  ┌───────────┐  │    │  ┌─────────────┐ │    │  ┌────────────┐ │
│  │Flutter Web│  │◄──►│  │ Static Files│ │    │  │ WeCom Auth │ │
│  │  Sidebar  │  │    │  │             │ │    │  │  Services  │ │
│  └───────────┘  │    │  └─────────────┘ │    │  └────────────┘ │
│                │    │        │         │    │        ▲        │
└─────────────────┘    │        ▼         │    │        │        │
                       │  ┌─────────────┐ │    │  ┌────────────┐ │
                       │  │ API Proxy   │ │◄──►│  │ Signature  │ │
                       │  │             │ │    │  │ Generation │ │
                       │  └─────────────┘ │    │  └────────────┘ │
                       └──────────────────┘    └─────────────────┘
```

## 功能特性

### ✨ 企业微信集成
- 🔐 企业微信身份验证
- 📱 JavaScript SDK 集成
- 🔑 JSSDK 签名生成
- 👥 内外部用户识别

### 🚀 技术特性
- ⚡ Flutter Web 单页应用
- 🔥 FastAPI 异步后端
- 🛡️ HTTPS 安全通信
- 🔄 自动访问令牌刷新
- 📦 Docker 容器化支持

### 🎯 企业级功能
- 🏢 企业微信侧边栏嵌入
- 💬 企业聊天功能集成
- 📊 用户行为分析
- 🔧 灵活配置管理

## 快速开始

### 环境要求

- **Flutter**: 3.9.2 或更高版本
- **Python**: 3.8 或更高版本
- **Node.js**: 16 或更高版本 (可选，用于开发工具)

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/Glucopilot-ai/wecom-sidebar.git
cd wecom-sidebar
```

2. **配置环境变量**
```bash
# 复制环境变量模板
cp api/.env.example api/.env

# 编辑配置文件
vim api/.env
```

3. **启动后端服务**
```bash
cd api/
pip install -r requirements.txt
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

4. **启动前端开发**
```bash
cd frontend/
flutter pub get
flutter run -d web
```

### 环境变量配置

在 `api/.env` 文件中配置以下变量：

```bash
# 企业微信配置
CORP_ID=你的企业ID
CORP_SECRET=你的应用密钥
AGENT_ID=你的应用AgentID

# 服务配置 (可选)
API_PORT=8000
DEBUG=true
```

## 开发指南

### 项目结构

```
wecom-sidebar/
├── api/                      # Python FastAPI 后端
│   ├── app.py               # 主应用文件
│   ├── requirements.txt     # Python 依赖
│   └── .env                 # 环境变量配置
├── frontend/                # Flutter Web 前端
│   ├── lib/
│   │   ├── main.dart       # 应用入口
│   │   └── wecom_js.dart   # 企业微信 JS 集成
│   └── pubspec.yaml        # Flutter 依赖
├── nginx/                   # Nginx 配置
│   └── wecom.jianantech.com.conf
├── deploy.sh               # 部署脚本
└── CLAUDE.md              # 开发指南
```

### 开发工作流

1. **后端开发**
```bash
cd api/
# 安装依赖
pip install -r requirements.txt

# 启动开发服务器
uvicorn app:app --reload --host 0.0.0.0 --port 8000

# 运行测试
python -m pytest tests/ --verbose
```

2. **前端开发**
```bash
cd frontend/
# 安装依赖
flutter pub get

# 启动开发服务器
flutter run -d web

# 代码分析
flutter analyze

# 运行测试
flutter test
```

3. **构建生产版本**
```bash
# 构建 Flutter Web
cd frontend/
flutter build web --release

# 部署脚本
./deploy.sh
```

## API 接口

### 健康检查
```http
GET /health
```

### 企业微信签名接口
```http
GET /wecom/jssdk-sign?url=<当前页面URL>
```

响应：
```json
{
    "signature": "签名字符串",
    "timestamp": "时间戳", 
    "nonceStr": "随机字符串",
    "corpId": "企业ID"
}
```

### 应用配置签名
```http
GET /wecom/agent-sign
```

## 部署说明

### 本地开发 + 远程部署模式

开发现在在本地 MacBook 进行，通过脚本部署到远程 Ubuntu 服务器。

#### 1. 本地开发环境设置

```bash
# 克隆项目到本地
git clone https://github.com/Glucopilot-ai/wecom-sidebar.git
cd wecom-sidebar

# 配置环境变量
cp api/.env.example api/.env
vim api/.env

# 本地开发
cd frontend/
flutter pub get
flutter run -d web

# 后端开发 (另一个终端)
cd api/
pip install -r requirements.txt
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

#### 2. 远程服务器要求
- Ubuntu 18.04+ 服务器
- SSH 访问权限
- Nginx 1.16+
- Python 3.8+
- SSL 证书

#### 3. 自动化部署

```bash
# 从本地部署到远程服务器
chmod +x deploy.sh
./deploy.sh

# 或指定特定服务器
./deploy.sh ubuntu@your-server.com
```

**部署流程：**
1. 本地构建 Flutter Web 应用
2. 打包所有必要文件
3. 通过 rsync 上传到远程服务器
4. 在远程服务器上执行部署脚本
5. 设置权限并重启服务

#### 4. 首次服务器配置

在远程服务器上执行一次：

```bash
# 创建 systemd 服务文件
sudo vim /etc/systemd/system/wecom-api.service
```

```ini
[Unit]
Description=WeCom API Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/wecom/api
Environment=PATH=/home/wecom/api/.venv/bin
ExecStart=/home/wecom/api/.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# 启用服务
sudo systemctl daemon-reload
sudo systemctl enable wecom-api
sudo systemctl start wecom-api

# SSL 证书配置
sudo certbot --nginx -d wecom.jianantech.com
```

### Docker 部署 (可选)

```bash
# 构建镜像
docker build -t wecom-sidebar .

# 运行容器
docker run -d \
  --name wecom-sidebar \
  -p 8000:8000 \
  -v $(pwd)/api/.env:/app/.env \
  wecom-sidebar
```

## 故障排除

### 常见问题

1. **企业微信签名验证失败**
   - 检查 `CORP_ID` 和 `CORP_SECRET` 配置
   - 确认应用权限设置正确
   - 验证时间戳是否同步

2. **前端无法连接后端**
   - 检查 API 服务是否正常运行
   - 确认跨域配置正确
   - 检查 Nginx 代理配置

3. **SSL 证书问题**
   - 确认证书文件路径正确
   - 检查证书是否过期
   - 验证域名解析设置

### 调试模式

启用调试日志：
```bash
# 后端调试
export DEBUG=true
uvicorn app:app --log-level debug

# 前端调试
flutter run -d web --debug
```

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交变更 (`git commit -m 'Add some amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 代码规范

- **Python**: 遵循 PEP 8 标准
- **Dart**: 遵循 Flutter 官方代码规范
- **提交信息**: 使用中文描述，简洁明了

## 许可证

本项目采用 [MIT License](LICENSE) 许可证。

## 技术支持

- 📧 邮箱: support@glucopilot.ai
- 🐛 问题反馈: [GitHub Issues](https://github.com/Glucopilot-ai/wecom-sidebar/issues)
- 📖 开发文档: [CLAUDE.md](CLAUDE.md)

---

**Glucopilot AI** - 企业级智能解决方案