import 'dart:js';
import 'dart:js_util';

bool hasWx() => context.hasProperty('wx');

dynamic _wx() => context['wx'];

dynamic _resolveJsMember(dynamic target, String name) {
  dynamic current = target;
  final visited = <int>{};

  while (current != null) {
    final id = identityHashCode(current);
    if (visited.contains(id)) {
      break;
    }
    visited.add(id);

    try {
      final value = getProperty(current, name);
      if (value != null) {
        return value;
      }
    } catch (_) {
      // Ignore lookup errors and traverse the prototype chain.
    }

    dynamic next;
    try {
      next = getProperty(current, '__proto__');
    } catch (_) {
      next = null;
    }
    if (next != null) {
      current = next;
      continue;
    }

    try {
      next = getProperty(current, 'prototype');
    } catch (_) {
      next = null;
    }
    if (next != null) {
      current = next;
      continue;
    }

    break;
  }

  return null;
}

bool hasWxMethod(String name) {
  final w = _wx();
  if (w == null) return false;
  try {
    final resolved = _resolveJsMember(w, name);
    if (resolved == null) {
      return false;
    }
    return resolved is JsFunction || resolved is Function;
  } catch (_) {
    return false;
  }
}

String wxSnapshot() {
  try {
    final w = _wx();
    if (w == null) return 'wx: <missing>';

    String wxTypeInfo = 'unknown';
    try {
      wxTypeInfo = w.toString();
    } catch (e) {
      wxTypeInfo = 'error reading type: $e';
    }

    final hasCfg = hasWxMethod('config');
    final hasAgentCfg = hasWxMethod('agentConfig');

    String wxVersion = 'unknown';
    try {
      wxVersion = getProperty(w, 'version')?.toString() ?? 'no version';
    } catch (e) {
      wxVersion = 'error getting version: $e';
    }

    return 'wx type: $wxTypeInfo | config=$hasCfg agentConfig=$hasAgentCfg | version=$wxVersion';
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
