// lib/models/item_display_settings.dart
// מודל לניהול הגדרות תצוגה per-item-type
// שיפור #1: ניהול מצב משופר לכל סוג פריט

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class ItemDisplaySettings extends Equatable {
  final String itemType;
  final double fontSize;
  final String fontFamily;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final double lineHeight;
  final double marginSize;
  final double paddingSize;
  final bool enableAnimations;
  final String texturePattern;
  final double brightness;
  final double contrast;
  final bool rtlMode;
  final TextDirection textDirection;

  const ItemDisplaySettings({
    required this.itemType,
    this.fontSize = 16.0,
    this.fontFamily = 'FrankRuhlCLM',
    this.backgroundColor = const Color(0xFFFFFCF5),
    this.textColor = const Color(0xFF2C2118),
    this.accentColor = const Color(0xFFD9B13E),
    this.lineHeight = 1.5,
    this.marginSize = 10.0,
    this.paddingSize = 10.0,
    this.enableAnimations = true,
    this.texturePattern = 'smooth',
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.rtlMode = true,
    this.textDirection = TextDirection.rtl,
  });

  ItemDisplaySettings copyWith({
    String? itemType,
    double? fontSize,
    String? fontFamily,
    Color? backgroundColor,
    Color? textColor,
    Color? accentColor,
    double? lineHeight,
    double? marginSize,
    double? paddingSize,
    bool? enableAnimations,
    String? texturePattern,
    double? brightness,
    double? contrast,
    bool? rtlMode,
    TextDirection? textDirection,
  }) {
    return ItemDisplaySettings(
      itemType: itemType ?? this.itemType,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      lineHeight: lineHeight ?? this.lineHeight,
      marginSize: marginSize ?? this.marginSize,
      paddingSize: paddingSize ?? this.paddingSize,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      texturePattern: texturePattern ?? this.texturePattern,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      rtlMode: rtlMode ?? this.rtlMode,
      textDirection: textDirection ?? this.textDirection,
    );
  }

  @override
  List<Object?> get props => [
        itemType,
        fontSize,
        fontFamily,
        backgroundColor,
        textColor,
        accentColor,
        lineHeight,
        marginSize,
        paddingSize,
        enableAnimations,
        texturePattern,
        brightness,
        contrast,
        rtlMode,
        textDirection,
      ];

  Map<String, dynamic> toJson() {
    return {
      'itemType': itemType,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'accentColor': accentColor.value,
      'lineHeight': lineHeight,
      'marginSize': marginSize,
      'paddingSize': paddingSize,
      'enableAnimations': enableAnimations,
      'texturePattern': texturePattern,
      'brightness': brightness,
      'contrast': contrast,
      'rtlMode': rtlMode,
      'textDirection': textDirection == TextDirection.rtl ? 'rtl' : 'ltr',
    };
  }

  factory ItemDisplaySettings.fromJson(Map<String, dynamic> json) {
    return ItemDisplaySettings(
      itemType: json['itemType'] ?? 'general',
      fontSize: json['fontSize'] ?? 16.0,
      fontFamily: json['fontFamily'] ?? 'FrankRuhlCLM',
      backgroundColor: Color(json['backgroundColor'] ?? 0xFFFFFCF5),
      textColor: Color(json['textColor'] ?? 0xFF2C2118),
      accentColor: Color(json['accentColor'] ?? 0xFFD9B13E),
      lineHeight: json['lineHeight'] ?? 1.5,
      marginSize: json['marginSize'] ?? 10.0,
      paddingSize: json['paddingSize'] ?? 10.0,
      enableAnimations: json['enableAnimations'] ?? true,
      texturePattern: json['texturePattern'] ?? 'smooth',
      brightness: json['brightness'] ?? 1.0,
      contrast: json['contrast'] ?? 1.0,
      rtlMode: json['rtlMode'] ?? true,
      textDirection: json['textDirection'] == 'ltr' 
          ? TextDirection.ltr 
          : TextDirection.rtl,
    );
  }

  static ItemDisplaySettings defaultForItemType(String itemType) {
    switch (itemType) {
      case 'pdf':
        return const ItemDisplaySettings(
          itemType: 'pdf',
          fontSize: 14.0,
          backgroundColor: Color(0xFFF5F5F5),
          texturePattern: 'paper',
        );
      case 'otzaria':
        return const ItemDisplaySettings(
          itemType: 'otzaria',
          fontSize: 18.0,
          fontFamily: 'FrankRuhlCLM',
          backgroundColor: Color(0xFFFDF6E3),
          texturePattern: 'parchment',
        );
      case 'docx':
        return const ItemDisplaySettings(
          itemType: 'docx',
          fontSize: 16.0,
          backgroundColor: Colors.white,
          texturePattern: 'smooth',
        );
      case 'audio':
        return const ItemDisplaySettings(
          itemType: 'audio',
          fontSize: 14.0,
          backgroundColor: Color(0xFF1A1A1A),
          textColor: Colors.white,
          texturePattern: 'smooth',
        );
      case 'calendar':
        return const ItemDisplaySettings(
          itemType: 'calendar',
          fontSize: 15.0,
          backgroundColor: Color(0xFFE8F4F8),
          texturePattern: 'grid',
        );
      default:
        return const ItemDisplaySettings(itemType: 'general');
    }
  }
}
