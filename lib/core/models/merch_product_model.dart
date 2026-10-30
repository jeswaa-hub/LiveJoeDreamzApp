import 'package:flutter/material.dart';
import 'package:dream_community_app/core/config/api_config.dart';

class MerchProductModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final double price;
  final bool isDonation;
  final String category;
  final List<String> sizesAvailable;
  final List<String> colorsAvailable;
  final int stockQuantity;
  final String stockStatus;
  final String? imageUrl;
  final String status;
  final String? createdAt;

  MerchProductModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.price = 0.0,
    this.isDonation = false,
    this.category = 'general',
    this.sizesAvailable = const [],
    this.colorsAvailable = const [],
    this.stockQuantity = 0,
    this.stockStatus = 'in',
    this.imageUrl,
    this.status = 'active',
    this.createdAt,
  });

  factory MerchProductModel.fromJson(Map<String, dynamic> json) {
    return MerchProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      isDonation: json['is_donation'] == true || json['is_donation'] == 1 || json['category'] == 'donation',
      category: json['category'] ?? 'general',
      sizesAvailable: json['sizes_available'] is List
          ? List<String>.from(json['sizes_available'])
          : [],
      colorsAvailable: json['colors_available'] is List
          ? List<String>.from(json['colors_available'])
          : [],
      stockQuantity: json['stock_quantity'] ?? 0,
      stockStatus: json['stock_status'] ?? 'in',
      imageUrl: _resolveUrl(json['image_url']),
      status: json['status'] ?? 'active',
      createdAt: json['created_at'],
    );
  }

  static String? _resolveUrl(String? path) => ApiConfig.resolveUrl(path);

  bool get isSoldOut => stockStatus == 'out' || stockQuantity == 0;

  Map<String, dynamic> toJson() => toDetailMap();

  Map<String, dynamic> toDetailMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'price': price,
      'description': description ?? '',
      'category': category,
      'status': status,
      'stock': stockQuantity,
      'sizes': sizesAvailable,
      'colors': colorsAvailable,
      'isDonation': isDonation,
      'imageUrl': imageUrl,
      'packages': isDonation
          ? [
              {
                'name': 'Birthday Freestyle Rap (Standard)',
                'desc': 'Up to 1 week delivery',
                'price': 25,
                'color': const Color(0xFF00DBE9),
                'vip': false,
              },
              {
                'name': 'Birthday Freestyle Rap (Rush)',
                'desc': '24-hour delivery',
                'price': 50,
                'color': const Color(0xFFFD18F5),
                'vip': false,
              },
              {
                'name': 'Birthday Bundle (T-Shirt + Freestyle)',
                'desc': 'Autographed tee incl.',
                'price': 100,
                'color': const Color(0xFFFFD700),
                'vip': true,
              },
              {
                'name': 'Birthday VIP Experience',
                'desc': 'Live Zoom rap + Tee + Song',
                'price': 250,
                'color': const Color(0xFF00DBE9),
                'vip': true,
              },
            ]
          : [],
    };
  }
}
