import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartStore extends ChangeNotifier {
  static final CartStore _instance = CartStore._();
  factory CartStore() => _instance;
  CartStore._();

  final List<Map<String, dynamic>> _items = [];
  bool _loaded = false;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;

  int get totalQty {
    int sum = 0;
    for (final item in _items) {
      sum += (item['qty'] as int?) ?? 1;
    }
    return sum;
  }

  double get subtotal {
    double sum = 0;
    for (final item in _items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final qty = (item['qty'] as int?) ?? 1;
      sum += price * qty;
    }
    return sum;
  }

  double get total => subtotal;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cart_items');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) _items.add(item);
          }
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart_items', jsonEncode(_items));
    notifyListeners();
  }

  Future<void> add(Map<String, dynamic> item) async {
    final existingIndex = _items.indexWhere((e) =>
        e['name'] == item['name'] &&
        e['size'] == item['size'] &&
        e['color'] == item['color'] &&
        e['isDonation'] == item['isDonation']);

    if (existingIndex != -1) {
      _items[existingIndex]['qty'] = ((_items[existingIndex]['qty'] as int?) ?? 1) + ((item['qty'] as int?) ?? 1);
    } else {
      _items.add(Map<String, dynamic>.from(item));
    }
    await _save();
  }

  Future<void> remove(int index) async {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      await _save();
    }
  }

  Future<void> updateQty(int index, int qty) async {
    if (index >= 0 && index < _items.length && qty > 0) {
      _items[index]['qty'] = qty;
      await _save();
    }
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
  }
}
