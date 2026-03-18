import 'dart:ui';

import 'package:flutter/material.dart';

class GuessSong {
  final num songId;
  final String title;
  final String type;
  final num bpm;
  final String artist;
  final String masterDs;
  final String masterCharter;
  final String remasterDs;
  final String remasterCharter;
  final String genre;
  final String version;
  List<String>? masterTags;

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

  String? bpmArrow;
  String? masterLevelArrow;
  String? remasterLevelArrow;
  String? versionArrow;

  GuessSong({
    required this.songId,
    required this.title,
    required this.type,
    required this.bpm,
    required this.artist,
    required this.masterDs,
    required this.masterCharter,
    required this.remasterDs,
    required this.remasterCharter,
    required this.genre,
    required this.version,
    this.masterTags,
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
    this.bpmArrow,
    this.masterLevelArrow,
    this.remasterLevelArrow,
    this.versionArrow,
  });
}