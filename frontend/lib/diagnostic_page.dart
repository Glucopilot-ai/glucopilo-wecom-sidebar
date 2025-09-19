import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'wecom_js.dart';

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  final List<DiagnosticResult> _results = [];
  bool _isRunning = false;
  String _currentTest = "";
  bool _showTextReport = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    // Test 1: Check WeCom SDK Loaded
    await _testWeComSDK();

    // Test 2: Check Current URL
    await _testCurrentURL();

    // Test 3: Test Backend Health
    await _testBackendHealth();

    // Test 3b: Test Backend Diagnostics
    await _testBackendDiagnostics();

    // Test 4: Test JSSDK Signature API
    await _testJSSDKSignature();

    // Test 5: Test Agent Signature API
    await _testAgentSignature();

    // Test 6: Test wx.config Availability
    await _testWxConfigAvailable();

    // Test 7: Test wx.agentConfig Availability
    await _testWxAgentConfigAvailable();

    // Test 8: Attempt wx.config Call
    await _attemptWxConfig();

    // Test 9: Attempt wx.agentConfig Call
    await _attemptWxAgentConfig();

    // Test 10: Check Browser Environment
    await _testBrowserEnvironment();

    setState(() => _isRunning = false);
  }

  Future<void> _addResult(String name, bool passed, String details, {Map<String, dynamic>? data}) async {
    setState(() {
      _currentTest = name;
      _results.add(DiagnosticResult(
        name: name,
        passed: passed,
        details: details,
        data: data,
        timestamp: DateTime.now(),
      ));
    });
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _testWeComSDK() async {
    try {
      final sdkLoaded = hasWx();
      final snapshot = wxSnapshot();

      await _addResult(
        "WeCom SDK加载检测",
        sdkLoaded,
        sdkLoaded ? "✅ WeCom SDK已加载" : "❌ WeCom SDK未加载",
        data: {"hasWx": sdkLoaded, "snapshot": snapshot},
      );
    } catch (e) {
      await _addResult("WeCom SDK加载检测", false, "❌ 检测失败: $e");
    }
  }

  Future<void> _testCurrentURL() async {
    try {
      final url = Uri.base.toString();
      final cleanUrl = url.split('#')[0];
      final isHttps = url.startsWith('https://');
      final isWeComDomain = url.contains('wecom.jianantech.com');

      await _addResult(
        "当前URL检测",
        isHttps && isWeComDomain,
        "URL: $cleanUrl",
        data: {
          "fullUrl": url,
          "cleanUrl": cleanUrl,
          "isHttps": isHttps,
          "isWeComDomain": isWeComDomain,
        },
      );
    } catch (e) {
      await _addResult("当前URL检测", false, "❌ 检测失败: $e");
    }
  }

  Future<void> _testBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse("https://wecom.jianantech.com/api/health"),
      ).timeout(const Duration(seconds: 5));

      final passed = response.statusCode == 200;
      final body = response.body;

      await _addResult(
        "后端健康检查 (/api/health)",
        passed,
        "HTTP ${response.statusCode}: ${body.length > 100 ? '${body.substring(0, 100)}...' : body}",
        data: {
          "statusCode": response.statusCode,
          "body": body,
        },
      );
    } catch (e) {
      await _addResult("后端健康检查", false, "❌ 连接失败: $e");
    }
  }

  Future<void> _testBackendDiagnostics() async {
    try {
      final response = await http.get(
        Uri.parse("https://wecom.jianantech.com/api/diagnostics"),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final envOk = data['environment']['CORP_ID_configured'] == true &&
                      data['environment']['CORP_SECRET_configured'] == true &&
                      data['environment']['AGENT_ID_configured'] == true;

        final testsOk = data['tests']['access_token']?['success'] == true &&
                        data['tests']['jsapi_ticket']?['success'] == true &&
                        data['tests']['agent_ticket']?['success'] == true;

        await _addResult(
          "后端配置诊断",
          envOk && testsOk,
          "环境变量=${envOk ? '✅' : '❌'}, API测试=${testsOk ? '✅' : '❌'}",
          data: data,
        );
      } else {
        await _addResult(
          "后端配置诊断",
          false,
          "❌ HTTP ${response.statusCode}",
        );
      }
    } catch (e) {
      await _addResult("后端配置诊断", false, "❌ 诊断失败: $e");
    }
  }

  Future<void> _testJSSDKSignature() async {
    try {
      final url = Uri.base.toString().split('#')[0];
      final apiUrl = "https://wecom.jianantech.com/api/wecom/jssdk-sign?url=${Uri.encodeComponent(url)}";

      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hasSignature = data['signature'] != null;
        final hasTimestamp = data['timestamp'] != null;
        final hasNonceStr = data['nonceStr'] != null;
        final hasAppId = data['appId'] != null;

        await _addResult(
          "JSSDK签名API测试",
          hasSignature && hasTimestamp && hasNonceStr && hasAppId,
          "响应字段: signature=${hasSignature}, timestamp=${hasTimestamp}, nonceStr=${hasNonceStr}, appId=${hasAppId}",
          data: data,
        );
      } else {
        await _addResult(
          "JSSDK签名API测试",
          false,
          "❌ HTTP ${response.statusCode}: ${response.body}",
        );
      }
    } catch (e) {
      await _addResult("JSSDK签名API测试", false, "❌ API调用失败: $e");
    }
  }

  Future<void> _testAgentSignature() async {
    try {
      final url = Uri.base.toString().split('#')[0];
      final apiUrl = "https://wecom.jianantech.com/api/wecom/agent-sign?url=${Uri.encodeComponent(url)}";

      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hasSignature = data['signature'] != null;
        final hasTimestamp = data['timestamp'] != null;
        final hasNonceStr = data['nonceStr'] != null;
        final hasCorpId = data['corpid'] != null;
        final hasAgentId = data['agentid'] != null;

        await _addResult(
          "Agent签名API测试",
          hasSignature && hasTimestamp && hasNonceStr && hasCorpId && hasAgentId,
          "响应字段: signature=${hasSignature}, timestamp=${hasTimestamp}, nonceStr=${hasNonceStr}, corpid=${hasCorpId}, agentid=${hasAgentId}",
          data: data,
        );
      } else {
        await _addResult(
          "Agent签名API测试",
          false,
          "❌ HTTP ${response.statusCode}: ${response.body}",
        );
      }
    } catch (e) {
      await _addResult("Agent签名API测试", false, "❌ API调用失败: $e");
    }
  }

  Future<void> _testWxConfigAvailable() async {
    try {
      final available = hasWxMethod('config');
      await _addResult(
        "wx.config方法可用性",
        available,
        available ? "✅ wx.config方法存在" : "❌ wx.config方法不存在",
        data: {"available": available},
      );
    } catch (e) {
      await _addResult("wx.config方法可用性", false, "❌ 检测失败: $e");
    }
  }

  Future<void> _testWxAgentConfigAvailable() async {
    try {
      final available = hasWxMethod('agentConfig');
      await _addResult(
        "wx.agentConfig方法可用性",
        available,
        available ? "✅ wx.agentConfig方法存在" : "❌ wx.agentConfig方法不存在",
        data: {"available": available},
      );
    } catch (e) {
      await _addResult("wx.agentConfig方法可用性", false, "❌ 检测失败: $e");
    }
  }

  Future<void> _attemptWxConfig() async {
    try {
      if (!hasWxMethod('config')) {
        await _addResult("wx.config配置尝试", false, "⚠️ 跳过: wx.config不可用");
        return;
      }

      final url = Uri.base.toString().split('#')[0];
      final response = await http.get(
        Uri.parse("https://wecom.jianantech.com/api/wecom/jssdk-sign?url=${Uri.encodeComponent(url)}"),
      );

      if (response.statusCode != 200) {
        await _addResult("wx.config配置尝试", false, "❌ 无法获取签名");
        return;
      }

      final config = jsonDecode(response.body);
      config['beta'] = true;
      config['debug'] = true;
      config['jsApiList'] = ['openEnterpriseChat', 'selectEnterpriseContact'];

      // Attempt to call wx.config
      try {
        wxConfig(config);
        await _addResult(
          "wx.config配置尝试",
          true,
          "✅ wx.config调用成功",
          data: config,
        );
      } catch (e) {
        await _addResult(
          "wx.config配置尝试",
          false,
          "❌ wx.config调用失败: $e",
          data: config,
        );
      }
    } catch (e) {
      await _addResult("wx.config配置尝试", false, "❌ 配置失败: $e");
    }
  }

  Future<void> _attemptWxAgentConfig() async {
    try {
      if (!hasWxMethod('agentConfig')) {
        await _addResult("wx.agentConfig配置尝试", false, "⚠️ 跳过: wx.agentConfig不可用");
        return;
      }

      final url = Uri.base.toString().split('#')[0];
      final response = await http.get(
        Uri.parse("https://wecom.jianantech.com/api/wecom/agent-sign?url=${Uri.encodeComponent(url)}"),
      );

      if (response.statusCode != 200) {
        await _addResult("wx.agentConfig配置尝试", false, "❌ 无法获取签名");
        return;
      }

      final config = jsonDecode(response.body);
      config['jsApiList'] = ['openEnterpriseChat'];

      // Attempt to call wx.agentConfig
      try {
        wxAgentConfig(config);
        await _addResult(
          "wx.agentConfig配置尝试",
          true,
          "✅ wx.agentConfig调用成功",
          data: config,
        );
      } catch (e) {
        await _addResult(
          "wx.agentConfig配置尝试",
          false,
          "❌ wx.agentConfig调用失败: $e",
          data: config,
        );
      }
    } catch (e) {
      await _addResult("wx.agentConfig配置尝试", false, "❌ 配置失败: $e");
    }
  }

  Future<void> _testBrowserEnvironment() async {
    try {
      final userAgent = "Flutter Web"; // This would need JS interop to get actual user agent
      final isInWeCom = Uri.base.toString().contains('wxwork') ||
                        Uri.base.queryParameters.containsKey('agentid');

      await _addResult(
        "浏览器环境检测",
        true,
        "环境信息收集完成",
        data: {
          "userAgent": userAgent,
          "isInWeCom": isInWeCom,
          "platform": "Web",
        },
      );
    } catch (e) {
      await _addResult("浏览器环境检测", false, "❌ 检测失败: $e");
    }
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    buffer.writeln("=== WeCom诊断报告 ===");
    buffer.writeln("生成时间: ${DateTime.now()}");
    buffer.writeln("总计: ${_results.length} 项测试");
    buffer.writeln("通过: ${_results.where((r) => r.passed).length}");
    buffer.writeln("失败: ${_results.where((r) => !r.passed).length}");
    buffer.writeln("");
    buffer.writeln("=== 测试结果 ===");

    for (int i = 0; i < _results.length; i++) {
      final result = _results[i];
      buffer.writeln("");
      buffer.writeln("${i + 1}. ${result.name}");
      buffer.writeln("   状态: ${result.passed ? '✅ 通过' : '❌ 失败'}");
      buffer.writeln("   详情: ${result.details}");

      if (result.data != null) {
        final dataStr = JsonEncoder.withIndent('     ').convert(result.data);
        buffer.writeln("   数据:");
        for (final line in dataStr.split('\n')) {
          buffer.writeln("     $line");
        }
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final passedTests = _results.where((r) => r.passed).length;
    final failedTests = _results.where((r) => !r.passed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("WeCom诊断工具"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostics,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: failedTests > 0 ? Colors.red[50] : Colors.green[50],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isRunning
                        ? "正在运行: $_currentTest"
                        : "诊断完成: ✅ $passedTests 通过, ❌ $failedTests 失败",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: failedTests > 0 ? Colors.red[700] : Colors.green[700],
                    ),
                  ),
                ),
                if (_isRunning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Toggle for text view
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("显示格式: ", style: TextStyle(fontWeight: FontWeight.bold)),
                ChoiceChip(
                  label: const Text("可视化"),
                  selected: !_showTextReport,
                  onSelected: (selected) {
                    if (selected) setState(() => _showTextReport = false);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("纯文本"),
                  selected: _showTextReport,
                  onSelected: (selected) {
                    if (selected) setState(() => _showTextReport = true);
                  },
                ),
              ],
            ),
          ),

          // Test Results
          Expanded(
            child: _showTextReport
                ? Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _generateTextReport(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    leading: Icon(
                      result.passed ? Icons.check_circle : Icons.error,
                      color: result.passed ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    title: Text(
                      result.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      result.details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      if (result.data != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          color: Colors.grey[100],
                          child: SelectableText(
                            JsonEncoder.withIndent('  ').convert(result.data),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          "时间: ${result.timestamp.toString()}",
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text("复制诊断报告"),
                    onPressed: _copyReport,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("重新运行诊断"),
                    onPressed: _isRunning ? null : _runDiagnostics,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyReport() {
    final report = _generateTextReport();

    // In real app, copy to clipboard
    print(report);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("诊断报告已复制到控制台（实际应用中会复制到剪贴板）")),
    );
  }
}

class DiagnosticResult {
  final String name;
  final bool passed;
  final String details;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  DiagnosticResult({
    required this.name,
    required this.passed,
    required this.details,
    this.data,
    required this.timestamp,
  });
}