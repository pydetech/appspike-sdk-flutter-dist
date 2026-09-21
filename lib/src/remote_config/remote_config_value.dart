import 'dart:convert';

import 'remote_config_status.dart';

class RemoteConfigValue {
  RemoteConfigValue(List<int>? value, this.source)
    : _value = value == null ? null : utf8.decode(value, allowMalformed: true);

  RemoteConfigValue.static() : _value = null, source = ValueSource.valueStatic;

  static const String defaultValueForString = '';
  static const int defaultValueForInt = 0;
  static const double defaultValueForDouble = 0.0;
  static const bool defaultValueForBool = false;

  final String? _value;

  final ValueSource source;

  String asString() => _value ?? defaultValueForString;

  bool asBool() {
    final value = _value;
    if (value == null) return defaultValueForBool;
    return _toBoolOrNull(value) ?? defaultValueForBool;
  }

  int asInt() {
    final value = _value;
    if (value == null) return defaultValueForInt;
    return int.tryParse(_trimAscii(value)) ?? defaultValueForInt;
  }

  double asDouble() {
    final value = _value;
    if (value == null) return defaultValueForDouble;
    return _parseFiniteNumber(value) ?? defaultValueForDouble;
  }
}

const Set<String> _truthyValues = <String>{'1', 'true', 't', 'yes', 'y', 'on'};
const Set<String> _falsyValues = <String>{
  '0',
  'false',
  'f',
  'no',
  'n',
  'off',
  '',
};

bool? _toBoolOrNull(String text) {
  final lowered = _trimAscii(text).toLowerCase();
  if (_truthyValues.contains(lowered)) return true;
  if (_falsyValues.contains(lowered)) return false;
  return null;
}

final RegExp _numberPattern = RegExp(
  r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$',
);

double? _parseFiniteNumber(String text) {
  final trimmed = _trimAscii(text);
  if (!_numberPattern.hasMatch(trimmed)) return null;
  final number = double.tryParse(trimmed);
  if (number == null || !number.isFinite) return null;
  return number;
}

const Set<int> _asciiWhitespace = <int>{0x20, 0x09, 0x0A, 0x0D, 0x0B, 0x0C};

String _trimAscii(String text) {
  var start = 0;
  var end = text.length;
  while (start < end && _asciiWhitespace.contains(text.codeUnitAt(start))) {
    start++;
  }
  while (end > start && _asciiWhitespace.contains(text.codeUnitAt(end - 1))) {
    end--;
  }
  return text.substring(start, end);
}
