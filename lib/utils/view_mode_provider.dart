import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { grid, list, compact }

class ViewModeProvider extends ChangeNotifier {
  ViewMode _mode = ViewMode.grid;
  double _fontSize = 16.0; // default body font size

  ViewMode get mode => _mode;
  double get fontSize => _fontSize;

  ViewModeProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('view_mode') ?? 'grid';
    _mode = ViewMode.values.firstWhere((e) => e.name == saved, orElse: () => ViewMode.grid);
    _fontSize = prefs.getDouble('font_size') ?? 16.0;
    notifyListeners();
  }

  Future<void> setMode(ViewMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('view_mode', mode.name);
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }
}
