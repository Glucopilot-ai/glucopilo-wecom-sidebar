# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WeCom-Sidebar is a Flutter web application with FastAPI backend that integrates with WeCom (WeChat Work) as a sidebar application. The frontend compiles to JavaScript for web deployment, while the backend provides WeCom authentication and JSAPI signature services.

## Core Development Principles

### 1. Minimum Design Philosophy
- **Minimum Features**: Only add minimum features at each step - no over-engineering
- **Fast Iteration**: Build → Test → Validate → Iterate quickly
- **Fail Fast, Fail Early**: 
  - Avoid fallback logic that might hide problems (no hardcoded answers for failed API calls)
  - Always provide detailed error messages to help pinpoint issues
  - Test early, catch issues before they propagate
- **Gradual Implementation**: Incremental deployment with rollback capability
- **Code Management**: Avoid create too many new files or version of script or functions

### 2. Service-First Architecture
- **Backend Business Logic**: All complex logic in Python services (single source of truth)
- **Frontend Minimal Logic**: Complex business logic via API calls, simple formatting/validation locally
- **Direct Function Calls**: FastAPI uses service classes directly for microsecond performance

### 3. Chinese Enterprise Standards
- **UI Language**: Chinese only (zh-CN)
- **Code/Variables**: English only for maintainability
- **Error Messages**: Chinese for all user-facing messages

### 4. Security & Compliance
- **Environment Variables**: Never commit secrets, use `.env` files
- **HTTPS Enforcement**: SSL certificates with automatic redirect
- **Enterprise Security**: WeChat Work signature validation for API security

## Architecture

- **Frontend**: Flutter web app (`frontend/`) that compiles to static files in `web/`
- **Backend**: Python FastAPI server (`api/app.py`) running on port 8000
- **Deployment**: Nginx reverse proxy with SSL, serving static files and proxying API calls
- **Integration**: JavaScript interop layer (`wecom_js.dart`) bridges Flutter and WeCom SDK

## Development Commands

### Flutter Frontend
```bash
cd frontend/
flutter pub get                 # Install dependencies
flutter run -d web             # Run development server
flutter test                   # Run tests
flutter analyze                # Lint code
flutter build web --release    # Build for production
```

### Python Backend
```bash
cd api/
# Check requirements.txt for exact dependencies
pip install -r requirements.txt
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

### Quality Checks (Before Commits)
```bash
# Frontend quality checks
cd frontend/ && flutter analyze
cd frontend/ && flutter test

# Backend quality checks
cd api/ && python -m pytest tests/ --verbose
cd api/ && python -m flake8 . --max-line-length=100
```

### Local to Remote Deployment
**IMPORTANT**: Never run deploy.sh automatically - it requires password input. Always provide the command for user to run manually.

```bash
./deploy.sh                     # Build locally, deploy to remote server
./deploy.sh ubuntu@server.com   # Deploy to specific server
```

**Build Signature**: The frontend displays a build signature at the bottom (format: "🔧 Build: v1.0.0 @ 2025-01-19 15:30:45 CST") to verify deployment updates and cache busting. Version number can be updated in `frontend/VERSION` file.

## Key Files and Structure

### Backend Service Architecture
- `api/app.py` - FastAPI server with WeCom authentication endpoints
- `api/services/` - Business logic services (if implemented)
- `api/.env` - Contains CORP_ID, CORP_SECRET, AGENT_ID credentials
- `api/requirements.txt` - Python dependencies

### Frontend Structure
- `frontend/lib/main.dart` - Main Flutter application entry
- `frontend/lib/wecom_js.dart` - WeCom JavaScript SDK integration layer
- `frontend/lib/services/` - API client services for backend communication
- `web/` - Compiled Flutter output (served by Nginx)

### Infrastructure
- `nginx/wecom.jianantech.com.conf` - Nginx configuration for SSL and routing
- `deploy.sh` - Deployment automation script

## WeCom Integration Patterns

The app uses WeCom's JavaScript SDK through dart:js interop. Key integration points:
- **Token Management**: Automatic access token refresh with caching
- **Signature Validation**: WeCom JS-SDK and agent signature generation
- **Enterprise Integration**: Sidebar embedding in WeCom client
- **User Context**: Internal/external user ID handling

## API Endpoints

- `GET /health` - Health check endpoint
- `GET /wecom/jssdk-sign` - Generate WeCom JS-SDK signatures
- `GET /wecom/agent-sign` - Generate agent configuration signatures

## Development Workflow

### Service-First Development (Recommended)
```python
# Example: Business logic with fail-fast principles
class WeChatService:
    def __init__(self):
        self.corp_id = os.getenv('CORP_ID')
        self.corp_secret = os.getenv('CORP_SECRET')
        
        # Fail fast - check required environment variables immediately
        if not self.corp_id or not self.corp_secret:
            raise ValueError(f"Missing required environment variables: CORP_ID={bool(self.corp_id)}, CORP_SECRET={bool(self.corp_secret)}")
    
    def generate_jssdk_signature(self, url: str) -> dict:
        try:
            # Complete signature generation logic
            return {"signature": "...", "timestamp": "...", "nonceStr": "..."}
        except Exception as e:
            # Fail fast - don't hide the error with fallback values
            raise RuntimeError(f"WeCom signature generation failed: {str(e)}")
    
    def validate_user_access(self, user_id: str) -> bool:
        if not user_id:
            raise ValueError("用户ID不能为空")  # Clear error message in Chinese
        # User validation logic - no silent fallbacks
        pass

# FastAPI adapter with fail-fast error handling
@router.get("/wecom/jssdk-sign")
async def jssdk_sign_endpoint(url: str):
    try:
        service = WeChatService()  # Will fail fast if env vars missing
        return service.generate_jssdk_signature(url)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"配置错误: {str(e)}")
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=f"签名生成失败: {str(e)}")
```

### Frontend API Integration
```dart
// Flutter - API calls with fail-fast error handling
Future<SignatureResult> getJssdkSignature(String url) async {
    try {
        return await apiClient.get('/wecom/jssdk-sign', {'url': url});
    } catch (e) {
        // Don't use fallback values - let the error surface
        throw Exception('WeCom签名获取失败: ${e.toString()}');
    }
}

// Flutter - Input validation with clear error messages
String formatUserDisplay(String userId, bool isInternal) {
    if (userId.isEmpty) {
        throw ArgumentError('用户ID不能为空');  // Fail fast on invalid input
    }
    return isInternal ? '内部用户: $userId' : '外部用户: $userId';
}
```

## Environment Configuration

### Required Environment Variables (.env)
```bash
CORP_ID=your_wecom_corp_id
CORP_SECRET=your_wecom_corp_secret  
AGENT_ID=your_wecom_agent_id
```

### Security Requirements
- Never commit `.env` files to git
- Use `.env.example` for documentation without actual values
- Implement proper error handling for missing environment variables
- Use HTTPS for all API communications

## Quality Gates (Before Any Commit)

### Fast Validation Checklist
- [ ] Business logic in service classes (not scattered in endpoints)
- [ ] Environment variables properly configured (no hardcoded secrets)
- [ ] Flutter analysis passes without warnings
- [ ] Python code follows PEP 8 standards
- [ ] Chinese error messages for all user-facing features
- [ ] WeCom integration tested in actual WeCom environment
- [ ] All tests pass (fail fast principle)
- [ ] Rollback procedure documented for changes

### Testing Strategy
- **Test Early**: Validate WeCom integration in development environment
- **Test Often**: Run automated tests on every code change
- **Test Real**: Test in actual WeCom client environment before deployment

## Chinese UI Standards

```python
# Error message example
class ValidationError:
    def __init__(self, field, code):
        self.field = field
        self.message = "企业微信配置无效"
        self.code = code
```

```dart
// Flutter Chinese messages
String getErrorMessage(String code) {
    final messages = {
        'invalid_signature': '签名验证失败',
        'network_error': '网络连接错误',
        'auth_failed': '身份验证失败',
        'server_error': '服务器错误',
    };
    return messages[code] ?? '未知错误';
}
```