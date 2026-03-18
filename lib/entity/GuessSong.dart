import 'dart:ui';

import 'package:flutter/material.dart';

class GuessSong {
  final String title;
  final String type;
  final num bpm;
  final String artist;
  final String masterLevel;
  final String masterCharter;
  final String remasterLevel;
  final String remasterCharter;
  final String genre;
  final String version;
  final List<String> masterTags;

  Color? titleBgColor;
  Color? typeBgColor;
  Color? bpmBgColor;
  Color? artistBgColor;
  Color? masterLevelBgColor;
  Color? masterCharterBgColor;
  Color? remasterLevelBgColor;
  Color? remasterCharterBgColor;
  Color? genreBgColor;
  Color? versionBgColor;
  List<Color?>? tagBgColors;

  GuessSong({
    required this.title,
    required this.type,
    required this.bpm,
    required this.artist,
    required this.masterLevel,
    required this.masterCharter,
    required this.remasterLevel,
    required this.remasterCharter,
    required this.genre,
    required this.version,
    required this.masterTags,
    this.titleBgColor = Colors.grey,
    this.typeBgColor = Colors.grey,
    this.bpmBgColor = Colors.grey,
    this.artistBgColor = Colors.grey,
    this.masterLevelBgColor = Colors.grey,
    this.masterCharterBgColor = Colors.grey,
    this.remasterLevelBgColor = Colors.grey,
    this.remasterCharterBgColor = Colors.grey,
    this.genreBgColor = Colors.grey,
    this.versionBgColor = Colors.grey,
    this.tagBgColors,
  });
}