import 'package:flutter/material.dart';

class CouponModel {
  final String id;
  final String title;
  final String description;
  final String code;
  final double discountAmount;
  final bool isPercentage;
  final double minPrice;
  final String expiryDate;
  final Color color;
  final Color iconColor;

  CouponModel({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.discountAmount,
    required this.isPercentage,
    required this.minPrice,
    required this.expiryDate,
    required this.color,
    required this.iconColor,
  });
}

class CouponService extends ChangeNotifier {
  static final CouponService _instance = CouponService._internal();
  factory CouponService() => _instance;
  CouponService._internal();

  final List<CouponModel> _wonCoupons = [];

  List<CouponModel> get wonCoupons => _wonCoupons;

  void addCoupon(CouponModel coupon) {
    _wonCoupons.insert(0, coupon); // En yeniyi başa ekle
    notifyListeners();
  }
}
