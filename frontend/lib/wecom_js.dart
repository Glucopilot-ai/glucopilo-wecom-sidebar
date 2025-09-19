import 'dart:js';
import 'dart:js_util';

bool hasWx() => context.hasProperty('wx');

dynamic _wx() => context['wx'];

bool hasWxMethod(String name) {
  final w = _wx();
  if (w == null) return false;
  try {
    return hasProperty(w, name) && getProperty(w, name) != null;
  } catch (_) {
    return false;
  }
}

String wxSnapshot() {
  try {
    final w = _wx();
    if (w == null) return 'wx: <missing>';
    
    // Check if wx is a constructor function (not initialized)
    String wxTypeInfo = 'unknown';
    try {
      final wxStr = w.toString();
      if (wxStr.contains('function') && wxStr.contains('this.a=a')) {
        wxTypeInfo = 'constructor-function (not initialized)';
      } else {
        wxTypeInfo = 'initialized-object';
      }
    } catch (e) {
      wxTypeInfo = 'error checking type: $e';
    }
    
    List<dynamic> keys = [];
    try {
      keys = callMethod(context['Object'], 'keys', [w]) as List<dynamic>? ?? [];
    } catch (e) {
      keys = ['<keys error: $e>'];
    }
    
    final hasCfg = hasWxMethod('config');
    final hasAgentCfg = hasWxMethod('agentConfig');
    
    // Additional debugging info
    String wxVersion = 'unknown';
    try {
      wxVersion = getProperty(w, 'version')?.toString() ?? 'no version';
    } catch (e) {
      wxVersion = 'error getting version: $e';
    }
    
    return 'wx type: $wxTypeInfo | keys: ${keys.join(', ')} | config=$hasCfg agentConfig=$hasAgentCfg | version=$wxVersion';
  } catch (e) {
    return 'wx snapshot error: $e';
  }
}

void wxConfig(Map<String, dynamic> config) {
  final w = _wx();
  if (w == null || !hasWxMethod('config')) {
    throw Exception("wx.config missing; snapshot: ${wxSnapshot()}");
  }
  callMethod(w, 'config', [jsify(config)]);
}

void wxAgentConfig(Map<String, dynamic> config) {
  final w = _wx();
  if (w == null || !hasWxMethod('agentConfig')) {
    throw Exception("wx.agentConfig missing; snapshot: ${wxSnapshot()}");
  }
  callMethod(w, 'agentConfig', [jsify(config)]);
}

void wxReady(Function callback) {
  final w = _wx();
  if (w != null && hasWxMethod('ready')) {
    callMethod(w, 'ready', [allowInterop(callback)]);
  }
}

void wxError(Function(dynamic) callback) {
  final w = _wx();
  if (w != null && hasWxMethod('error')) {
    callMethod(w, 'error', [allowInterop(callback)]);
  }
}

void wxOpenEnterpriseChat({String userIds = "", String externalUserIds = ""}) {
  final w = _wx();
  if (w == null || !hasWxMethod('openEnterpriseChat')) {
    throw Exception("wx.openEnterpriseChat missing; snapshot: ${wxSnapshot()}");
  }
  callMethod(w, 'openEnterpriseChat', [
    jsify({
      "userIds": userIds,
      "externalUserIds": externalUserIds,
      "success": allowInterop(() => print("openEnterpriseChat success")),
      "fail": allowInterop((err) => print("openEnterpriseChat failed: $err")),
    })
  ]);
}