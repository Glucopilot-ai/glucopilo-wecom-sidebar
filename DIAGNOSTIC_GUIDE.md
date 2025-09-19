# WeCom Integration Diagnostic Guide

## 🔧 Comprehensive Diagnostic Tool

We've added a powerful diagnostic tool to help identify exactly where the WeCom integration is failing.

## How to Use

### 1. Deploy the Updated Code
```bash
# Build and deploy with diagnostics
./deploy.sh
```

### 2. Access the Diagnostic Tool

In the WeCom sidebar application:
1. Click the **"诊断工具"** (orange button) on the main page
2. The tool will automatically run 10+ comprehensive tests

## What It Tests

### Frontend Tests
1. **WeCom SDK加载检测** - Checks if WeCom JavaScript SDK is loaded
2. **当前URL检测** - Validates URL format and HTTPS
3. **wx.config方法可用性** - Checks if wx.config method exists
4. **wx.agentConfig方法可用性** - Checks if wx.agentConfig method exists
5. **浏览器环境检测** - Detects browser and WeCom client environment

### Backend Tests
6. **后端健康检查** - Tests if backend API is responding
7. **后端配置诊断** - Verifies environment variables (.env configuration)
8. **JSSDK签名API测试** - Tests JSSDK signature generation
9. **Agent签名API测试** - Tests Agent signature generation

### Integration Tests
10. **wx.config配置尝试** - Actually attempts to call wx.config
11. **wx.agentConfig配置尝试** - Actually attempts to call wx.agentConfig

## Reading the Results

### ✅ Green Check = Test Passed
The component is working correctly.

### ❌ Red X = Test Failed
This component has an issue. Click to expand and see detailed error information.

## Common Issues and Solutions

### Issue: "WeCom SDK未加载"
**Cause**: Not running in WeCom client
**Solution**: Open the app inside WeCom client, not regular browser

### Issue: "后端配置诊断 Failed - Environment variables"
**Cause**: Missing or incorrect .env file on server
**Solution**:
```bash
# On server
cd /home/wecom/api
cp .env.example .env
# Edit .env with correct CORP_ID, CORP_SECRET, AGENT_ID
sudo systemctl restart wecom-api
```

### Issue: "JSSDK签名API测试 Failed - HTTP 500"
**Cause**: Invalid WeCom credentials
**Solution**: Verify CORP_ID and CORP_SECRET are correct in .env

### Issue: "wx.config配置尝试 Failed"
**Cause**:
1. Wrong domain in WeCom app settings
2. URL mismatch between request and WeCom configuration
3. Invalid signature

**Solution**:
1. Check WeCom admin panel → App settings → Trusted domains
2. Ensure the URL includes `https://wecom.jianantech.com`
3. Check the diagnostic data for signature details

## Backend Diagnostics Endpoint

You can also directly test the backend diagnostics:
```
https://wecom.jianantech.com/api/diagnostics
```

This returns JSON with:
- Environment variable status
- Cache status
- Access token test
- JSAPI ticket test
- Agent ticket test
- Signature generation test

## Copying Diagnostic Report

Click **"复制诊断报告"** button to get a full text report for sharing with support.

## Key Points to Check

1. **Environment Detection**: `config=false, agentConfig=false` means the WeCom SDK methods aren't being recognized
2. **URL Validation**: Must be HTTPS and match configured domain
3. **API Connectivity**: All API endpoints must return 200 OK
4. **Signature Fields**: All required fields must be present (signature, timestamp, nonceStr, etc.)

## Still Having Issues?

If diagnostics show all tests passing but WeCom still shows `config=false`:

1. **Clear Browser Cache**: Force refresh with Ctrl+Shift+R
2. **Check WeCom Version**: Ensure you're using latest WeCom client
3. **Verify App Permissions**: Check WeCom admin panel for app permissions
4. **Domain Whitelist**: Ensure `wecom.jianantech.com` is in WeCom's trusted domains
5. **HTTPS Certificate**: Verify SSL certificate is valid and not self-signed

## Debug Mode

The diagnostic tool enables `debug: true` in wx.config, which will show detailed logs in the browser console.

Open browser DevTools (F12) to see WeCom SDK debug output.