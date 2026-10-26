import 'package:flutter/material.dart';

/// User-chosen categories. Colors never imply urgency, health, or completion.
class EventColors {
  const EventColors(
    this.id,
    this.name,
    this.light,
    this.onLight,
    this.dark,
    this.onDark,
  );
  final String id, name;
  final Color light, onLight, dark, onDark;
  static const choices = [
    EventColors(
      'rose',
      'Rose',
      Color(0xFFF6E1E6),
      Color(0xFF612B3C),
      Color(0xFF442A36),
      Color(0xFFFFDAE5),
    ),
    EventColors(
      'lavender',
      'Lavender',
      Color(0xFFEAE3F7),
      Color(0xFF4B3468),
      Color(0xFF3C3053),
      Color(0xFFEDE0FF),
    ),
    EventColors(
      'plum',
      'Plum',
      Color(0xFFF0E0F0),
      Color(0xFF612D60),
      Color(0xFF513449),
      Color(0xFFFFDFF8),
    ),
    EventColors(
      'ocean',
      'Ocean',
      Color(0xFFDDEBF7),
      Color(0xFF254E70),
      Color(0xFF253E54),
      Color(0xFFDCEFFF),
    ),
    EventColors(
      'teal',
      'Teal',
      Color(0xFFDCEFEA),
      Color(0xFF235B52),
      Color(0xFF24463F),
      Color(0xFFD5FFF0),
    ),
    EventColors(
      'sage',
      'Sage',
      Color(0xFFE4EEDC),
      Color(0xFF3F5730),
      Color(0xFF38472E),
      Color(0xFFE7F8D8),
    ),
    EventColors(
      'sand',
      'Sand',
      Color(0xFFF3E9CF),
      Color(0xFF685021),
      Color(0xFF50432B),
      Color(0xFFFFEBC5),
    ),
    EventColors(
      'peach',
      'Peach',
      Color(0xFFF8E3D9),
      Color(0xFF713D28),
      Color(0xFF573B31),
      Color(0xFFFFE4D4),
    ),
    EventColors(
      'slate',
      'Slate',
      Color(0xFFE5E8EE),
      Color(0xFF414C60),
      Color(0xFF343C4A),
      Color(0xFFE4EBF8),
    ),
  ];
  static EventColors fromId(String id) =>
      choices.where((c) => c.id == id).firstOrNull ?? choices.first;
  Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
  Color foreground(Brightness brightness) =>
      brightness == Brightness.dark ? onDark : onLight;
}
