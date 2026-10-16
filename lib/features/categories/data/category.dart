import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class Category {
  const Category({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(
        int.parse((json['color'] as String).replaceFirst('#', '0xFF')),
      ),
    );
  }

  String get colorHex => '#${color.toARGB32().toRadixString(16).substring(2)}';
}

const categoryColorSwatches = <Color>[
  AppColors.entrada,
  AppColors.saida,
  AppColors.diario,
  AppColors.economia,
  AppColors.cartao,
  Color(0xFF1E88E5),
  Color(0xFFF9A825),
  Color(0xFF8D6E63),
];
