import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:yaml/yaml.dart';

class RuntimeConfigFragment extends StatefulWidget {
  final Profile profile;

  const RuntimeConfigFragment({
    super.key,
    required this.profile,
  });

  @override
  State<RuntimeConfigFragment> createState() => _RuntimeConfigFragmentState();
}

class _RuntimeConfigFragmentState extends State<RuntimeConfigFragment> {
  String? _content;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRuntimeConfig();
  }

  Future<void> _loadRuntimeConfig() async {
    try {
      final config = context.read<Config>();
      final clashConfig = context.read<ClashConfig>();
      final profilePath = await appPath.getProfilePath(widget.profile.id);
      if (profilePath == null) {
        setState(() {
          _content = null;
          _isLoading = false;
          _error = appLocalizations.nullProfileDesc;
        });
        return;
      }
      final file = File(profilePath);
      if (!await file.exists()) {
        setState(() {
          _content = null;
          _isLoading = false;
          _error = appLocalizations.nullProfileDesc;
        });
        return;
      }
      final yamlString = await file.readAsString();
      final overrideDns = config.overrideDns;
      final overrides = jsonDecode(jsonEncode(clashConfig.toJson()))
          as Map<String, dynamic>;
      final mergedYaml = _mergeAndEncodeYaml(yamlString, overrides, overrideDns);
      if (!mounted) return;
      setState(() {
        _content = mergedYaml;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _content = null;
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_content == null || _content!.isEmpty) {
      return Center(
        child: Text(appLocalizations.nullProfileDesc),
      );
    }
    return _YamlViewer(content: _content!);
  }
}

class _YamlViewer extends StatefulWidget {
  final String content;

  const _YamlViewer({required this.content});

  @override
  State<_YamlViewer> createState() => _YamlViewerState();
}

class _YamlViewerState extends State<_YamlViewer> {
  late final CodeLineEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CodeEditor(
      readOnly: true,
      focusNode: _focusNode,
      showCursorWhenReadOnly: false,
      controller: _controller,
      shortcutsActivatorsBuilder: const DefaultCodeShortcutsActivatorsBuilder(),
      indicatorBuilder: (
        context,
        editingController,
        chunkController,
        notifier,
      ) {
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            DefaultCodeChunkIndicator(
              width: 20,
              controller: chunkController,
              notifier: notifier,
            ),
          ],
        );
      },
      style: CodeEditorStyle(
        fontSize: 14,
        codeTheme: CodeHighlightTheme(
          languages: {
            'yaml': CodeHighlightThemeMode(mode: langYaml),
          },
          theme: atomOneLightTheme,
        ),
      ),
    );
  }
}

dynamic _yamlToNative(dynamic yaml) {
  if (yaml is YamlMap) {
    final map = <String, dynamic>{};
    for (final entry in yaml.entries) {
      map[entry.key.toString()] = _yamlToNative(entry.value);
    }
    return map;
  } else if (yaml is YamlList) {
    return yaml.map((e) => _yamlToNative(e)).toList();
  } else {
    return yaml;
  }
}

String _mergeAndEncodeYaml(
    String yamlString, Map<String, dynamic> overrides, bool overrideDns) {
  final yamlDoc = loadYaml(yamlString);
  if (yamlDoc == null) return '';
  final config = _yamlToNative(yamlDoc);
  if (config is! Map<String, dynamic>) return '';
  _applyOverrides(config, overrides, overrideDns);
  return _encodeYaml(config);
}

void _applyOverrides(Map<String, dynamic> config,
    Map<String, dynamic> overrides, bool overrideDns) {
  const directOverrideKeys = [
    'mixed-port',
    'allow-lan',
    'mode',
    'log-level',
    'ipv6',
    'find-process-mode',
    'external-controller',
    'keep-alive-interval',
    'unified-delay',
    'tcp-concurrent',
    'geodata-loader',
    'global-ua',
  ];

  for (final key in directOverrideKeys) {
    final value = overrides[key];
    if (value != null) {
      config[key] = value;
    }
  }

  config['port'] = 0;
  config['socks-port'] = 0;
  config['external-ui'] = '';
  config['external-ui-url'] = '';
  config['interface-name'] = '';

  if (overrides['tun'] != null) {
    final tunOverride = overrides['tun'] as Map<String, dynamic>;
    final tun =
        (config['tun'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    for (final entry in tunOverride.entries) {
      tun[entry.key] = entry.value;
    }
    config['tun'] = tun;
  }

  if (overrideDns && overrides['dns'] != null) {
    config['dns'] = overrides['dns'];
  }

  if (overrides['geox-url'] != null) {
    config['geox-url'] = overrides['geox-url'];
  }

  if (overrides['hosts'] != null && (overrides['hosts'] as Map).isNotEmpty) {
    final hosts =
        (config['hosts'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    for (final entry in (overrides['hosts'] as Map<String, dynamic>).entries) {
      hosts[entry.key] = entry.value;
    }
    config['hosts'] = hosts;
  }

  final profile =
      (config['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};
  profile['store-selected'] = false;
  config['profile'] = profile;

  if (overrides['udp'] == true) {
    final proxies = config['proxies'] as List<dynamic>?;
    if (proxies != null) {
      for (final proxy in proxies) {
        if (proxy is Map<String, dynamic>) {
          proxy['udp'] = true;
        }
      }
    }
    final proxyGroups = config['proxy-groups'] as List<dynamic>?;
    if (proxyGroups != null) {
      for (final group in proxyGroups) {
        if (group is Map<String, dynamic>) {
          group['udp'] = true;
        }
      }
    }
    final proxyProviders = config['proxy-providers'] as Map<String, dynamic>?;
    if (proxyProviders != null) {
      for (final entry in proxyProviders.entries) {
        if (entry.value is Map<String, dynamic>) {
          final provider = entry.value as Map<String, dynamic>;
          final override =
              provider['override'] as Map<String, dynamic>? ??
                  <String, dynamic>{};
          override['udp'] = true;
          provider['override'] = override;
        }
      }
    }
  }
}

String _encodeYaml(dynamic value, {int indent = 0}) {
  final buffer = StringBuffer();
  _writeYamlValue(buffer, value, indent, false);
  return buffer.toString();
}

void _writeYamlValue(
    StringBuffer buffer, dynamic value, int indent, bool isInList) {
  if (value is Map) {
    _writeYamlMap(buffer, value, indent, isInList);
  } else if (value is List) {
    _writeYamlList(buffer, value, indent, isInList);
  } else {
    buffer.write(_formatScalar(value));
  }
}

void _writeYamlMap(
    StringBuffer buffer, Map map, int indent, bool isInList) {
  final entries = map.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final key = entry.key;
    final value = entry.value;

    if (i > 0 || !isInList) {
      buffer.write('${'  ' * indent}$key:');
    } else {
      buffer.write('$key:');
    }

    if (value is Map || value is List) {
      buffer.writeln();
      _writeYamlValue(buffer, value, indent + 1, false);
    } else {
      buffer.writeln(' ${_formatScalar(value)}');
    }
  }
}

void _writeYamlList(
    StringBuffer buffer, List list, int indent, bool isInList) {
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    final prefix = '${'  ' * indent}- ';

    if (item is Map) {
      final entries = item.entries.toList();
      if (entries.isEmpty) {
        buffer.writeln('$prefix{}');
        continue;
      }
      buffer.write(prefix);
      buffer.write('${entries.first.key}:');
      final firstValue = entries.first.value;
      if (firstValue is Map || firstValue is List) {
        buffer.writeln();
        _writeYamlValue(buffer, firstValue, indent + 2, false);
      } else {
        buffer.writeln(' ${_formatScalar(firstValue)}');
      }
      for (var j = 1; j < entries.length; j++) {
        final entry = entries[j];
        buffer.write('${'  ' * (indent + 1)}${entry.key}:');
        final v = entry.value;
        if (v is Map || v is List) {
          buffer.writeln();
          _writeYamlValue(buffer, v, indent + 2, false);
        } else {
          buffer.writeln(' ${_formatScalar(v)}');
        }
      }
    } else if (item is List) {
      buffer.writeln(prefix);
      _writeYamlValue(buffer, item, indent + 1, false);
    } else {
      buffer.writeln('$prefix${_formatScalar(item)}');
    }
  }
}

String _formatScalar(dynamic value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is int || value is double) return value.toString();
  if (value is String) {
    if (value.isEmpty) return '""';
    if (value.contains('\n') ||
        value.contains(': ') ||
        value.contains(' #') ||
        value.startsWith('- ') ||
        value.startsWith('!') ||
        value.startsWith('&') ||
        value.startsWith('*') ||
        value.startsWith('?') ||
        value.startsWith('{') ||
        value.startsWith('}') ||
        value.startsWith('[') ||
        value.startsWith(']') ||
        value.startsWith(',') ||
        value.startsWith('@') ||
        value.startsWith('`') ||
        value.startsWith('"') ||
        value.startsWith("'") ||
        value == 'true' ||
        value == 'false' ||
        value == 'null' ||
        _looksLikeNumber(value)) {
      return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
    }
    return value;
  }
  return value.toString();
}

bool _looksLikeNumber(String s) {
  return double.tryParse(s) != null;
}

class LongPressDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onLongPress;
  final Duration duration;

  const LongPressDetector({
    super.key,
    required this.child,
    required this.onLongPress,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<LongPressDetector> createState() => _LongPressDetectorState();
}

class _LongPressDetectorState extends State<LongPressDetector> {
  Timer? _timer;

  void _onPointerDown(PointerDownEvent event) {
    _timer?.cancel();
    _timer = Timer(widget.duration, widget.onLongPress);
  }

  void _onPointerUp(PointerUpEvent event) {
    _timer?.cancel();
    _timer = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
