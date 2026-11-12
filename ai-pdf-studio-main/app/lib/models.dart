import 'package:flutter/material.dart';

class PdfDocumentModel {
  const PdfDocumentModel({
    required this.name,
    required this.path,
    required this.pages,
    required this.updated,
    this.favorite = false,
  });

  final String name;
  final String path;
  final int pages;
  final String updated;
  final bool favorite;

  factory PdfDocumentModel.fromJson(Map<dynamic, dynamic> json) => PdfDocumentModel(
        name: json['title'] as String? ?? (json['path'] as String).split(RegExp(r'[/\\]')).last,
        path: json['path'] as String,
        pages: (json['pageCount'] as num?)?.toInt() ?? 0,
        updated: json['updatedAt'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
      );

  PdfDocumentModel copyWith({bool? favorite}) => PdfDocumentModel(
        name: name,
        path: path,
        pages: pages,
        updated: updated,
        favorite: favorite ?? this.favorite,
      );
}

class PdfPageModel {
  const PdfPageModel({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

class PdfDocumentDetails {
  const PdfDocumentDetails({required this.pageCount, required this.pages});

  final int pageCount;
  final List<PdfPageModel> pages;

  factory PdfDocumentDetails.fromJson(Map<dynamic, dynamic> info, Map<dynamic, dynamic> extracted) =>
      PdfDocumentDetails(
        pageCount: (info['pageCount'] as num?)?.toInt() ?? 0,
        pages: ((extracted['pages'] as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>())
            .map((page) => PdfPageModel(
                  pageNumber: (page['pageNumber'] as num).toInt(),
                  text: page['text'] as String? ?? '',
                ))
            .toList(),
      );

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.citation,
  });

  final String text;
  final bool isUser;
  final String? citation;
}

class ToolDefinition {
  const ToolDefinition(this.label, this.description, this.icon, this.color);

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}
