import 'dart:convert';

import 'package:flutter/material.dart';

import '../database_helper.dart';

// Read-only database diagnostics for T1/T4/T5 evidence:
// PRAGMA user_version, foreign_keys, foreign_key_list(cards),
// index_list(cards), plus the Part I rows and catalogue rows.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, Object?>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.helper.diagnostics();
      debugPrint('DIAGNOSTICS ${jsonEncode(data)}');
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Diagnostics failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = 'Could not read diagnostics: $error');
    }
  }

  String _rows(Object? v) {
    if (v is List) {
      if (v.isEmpty) return '  (none)';
      return v.map((r) => '  $r').join('\n');
    }
    return '  $v';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database diagnostics'),
        actions: [
          IconButton(
              tooltip: 'Re-run',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final e in d.entries) ...[
                      Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(_rows(e.value),
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 11.5)),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
    );
  }
}
