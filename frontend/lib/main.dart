import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'wecom_js.dart';
import 'diagnostic_page.dart';

// Build signature for deployment tracking
const String _buildSignature = String.fromEnvironment('BUILD_TIMESTAMP', defaultValue: 'dev-build');

void main() {
  runApp(const WeComApp());
}

class WeComApp extends StatelessWidget {
  const WeComApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '企微Copilot',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = "正在等待企微环境...";
  String _snapshot = "";
  final _userIdsController = TextEditingController();
  final _extIdsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initWeCom();
  }

  Future<void> _initWeCom() async {
    // Give WeCom SDK time to load
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Probe environment
    final snap = wxSnapshot();
    setState(() => _snapshot = snap);

    if (!hasWx()) {
      setState(() => _status =
          "⚠️ 未检测到企微环境，请在企业微信客户端中打开。\n📊 快照: $snap\n🌐 URL: ${Uri.base.toString()}\n🖥️ UserAgent: ${identical(0, 0.0) ? 'Web' : 'Flutter'}");
      return;
    }

    final hasCfg = hasWxMethod('config');
    final hasAgent = hasWxMethod('agentConfig');
    setState(() => _status = "✅ 检测到企微环境。config=$hasCfg, agentConfig=$hasAgent\n📊 详细信息: $snap");

    final url = Uri.base.toString().split('#')[0];

    try {
      // 1) If config exists, do wx.config first (with SDK debug=true to log issues)
      if (hasCfg) {
        setState(() => _status += " | 正在获取JSSDK签名...");
        
        final res = await http.get(Uri.parse("https://wecom.jianantech.com/api/wecom/jssdk-sign?url=${Uri.encodeComponent(url)}"));
        
        if (res.statusCode != 200) {
          throw Exception("JSSDK签名请求失败: HTTP ${res.statusCode} - ${res.body}");
        }
        
        final cfg = jsonDecode(res.body);
        if (cfg['signature'] == null) {
          throw Exception("JSSDK签名响应无效: ${res.body}");
        }
        
        cfg['beta'] = true;
        cfg['debug'] = true; // turn on SDK verbose logs
        cfg['jsApiList'] = ['openEnterpriseChat', 'selectEnterpriseContact'];

        setState(() => _status += " | 调用wx.config...");
        wxConfig(cfg);

        wxReady(() => setState(() => _status = "🎉 wx.ready 准备就绪 (wx.config完成)"));
        wxError((err) => setState(() => _status = "❌ wx.error 错误: $err"));
      } else {
        setState(() => _status += " | wx.config不可用，跳过...");
      }

      // 2) If agentConfig exists, also inject app-level ticket
      if (hasAgent) {
        setState(() => _status += " | 正在获取Agent签名...");
        
        final res2 = await http.get(Uri.parse("https://wecom.jianantech.com/api/wecom/agent-sign?url=${Uri.encodeComponent(url)}"));
        
        if (res2.statusCode != 200) {
          throw Exception("Agent签名请求失败: HTTP ${res2.statusCode} - ${res2.body}");
        }
        
        final agentCfg = jsonDecode(res2.body);
        if (agentCfg['signature'] == null) {
          throw Exception("Agent签名响应无效: ${res2.body}");
        }
        
        agentCfg['jsApiList'] = ['openEnterpriseChat'];

        setState(() => _status += " | 调用wx.agentConfig...");
        wxAgentConfig(agentCfg);
        setState(() => _status += " | agentConfig ✅");
      } else {
        setState(() => _status += " | agentConfig不可用");
      }
    } catch (e) {
      setState(() => _status = "❌ 初始化错误: $e\n📊 环境快照: $snap\n🌐 当前URL: $url");
    }
  }

  void _openChat() {
    final userIds = _userIdsController.text.trim();
    final extIds = _extIdsController.text.trim();
    try {
      wxOpenEnterpriseChat(userIds: userIds, externalUserIds: extIds);
    } catch (e) {
      setState(() => _status = "打开企业聊天错误: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("企微Copilot"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("侧边栏宽度: ${w.toStringAsFixed(0)} px",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SelectableText(_status, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text("环境快照"),
                  initiallyExpanded: false,
                  children: [
                    SelectableText(_snapshot, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _initWeCom,
                        child: const Text("重新初始化"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DiagnosticPage()),
                          );
                        },
                        icon: const Icon(Icons.medical_services),
                        label: const Text("诊断工具"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _userIdsController,
                  decoration: const InputDecoration(
                    labelText: "内部用户ID (分号分隔)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _extIdsController,
                  decoration: const InputDecoration(
                    labelText: "外部用户ID (分号分隔)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("打开企业聊天", style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 300),
                const Center(
                  child: Text("--- 内容结束 ---", style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      "🔧 Build: $_buildSignature",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
