import 'package:flutter/material.dart';

class PdfDocumentModel {
  const PdfDocumentModel({
    required this.name,
    required this.path,
    required this.pages,
    required this.updated,
    this.favorite = false,
    this.lastPage = 1,
  });

  final String name;
  final String path;
  final int pages;
  final String updated;
  final bool favorite;
  final int lastPage;

  factory PdfDocumentModel.fromJson(Map<dynamic, dynamic> json) => PdfDocumentModel(
        name: json['title'] as String? ?? (json['path'] as String).split(RegExp(r'[/\\]')).last,
        path: json['path'] as String,
        pages: (json['pageCount'] as num?)?.toInt() ?? 0,
        updated: json['updatedAt'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
        lastPage: (json['lastPage'] as num?)?.toInt() ?? 1,
      );

  PdfDocumentModel copyWith({bool? favorite, int? lastPage}) => PdfDocumentModel(
        name: name,
        path: path,
        pages: pages,
        updated: updated,
        favorite: favorite ?? this.favorite,
        lastPage: lastPage ?? this.lastPage,
      );
}

class PdfPageModel {
  const PdfPageModel({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

class PdfDocumentDetails {
  const PdfDocumentDetails({
    required this.pageCount,
    required this.pages,
    this.title,
    this.author,
    this.fileSizeBytes,
    this.encrypted = false,
  });

  final int pageCount;
  final List<PdfPageModel> pages;
  final String? title;
  final String? author;
  final int? fileSizeBytes;
  final bool encrypted;

  factory PdfDocumentDetails.fromJson(Map<dynamic, dynamic> info, Map<dynamic, dynamic> extracted) =>
      PdfDocumentDetails(
        pageCount: (info['pageCount'] as num?)?.toInt() ?? 0,
        title: info['title'] as String?,
        author: info['author'] as String?,
        fileSizeBytes: (info['fileSizeBytes'] as num?)?.toInt(),
        encrypted: info['encrypted'] as bool? ?? false,
        pages: ((extracted['pages'] as List<dynamic>? ?? const [])
            .cast<Map<dynamic, dynamic>>())
            .map((page) => PdfPageModel(
                  pageNumber: (page['pageNumber'] as num).toInt(),
                  text: page['text'] as String? ?? '',
                ))
            .toList(),
      );
}

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
