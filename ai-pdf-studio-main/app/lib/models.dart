import 'package:flutter/material.dart';

class PdfDocumentModel {
  const PdfDocumentModel({
    required this.name,
    required this.path,
    required this.pages,
    required this.updated,
    this.favorite = false,
    this.lastPage = 1,
    this.status = 'available',
    this.note = '',
    this.tags = const [],
  });

  final String name;
  final String path;
  final int pages;
  final String updated;
  final bool favorite;
  final int lastPage;
  final String status;
  final String note;
  final List<String> tags;

  factory PdfDocumentModel.fromJson(Map<dynamic, dynamic> json) => PdfDocumentModel(
        name: json['title'] as String? ?? (json['path'] as String).split(RegExp(r'[/\\]')).last,
        path: json['path'] as String,
        pages: (json['pageCount'] as num?)?.toInt() ?? 0,
        updated: json['updatedAt'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
        lastPage: (json['lastPage'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'available',
        note: json['note'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      );

  PdfDocumentModel copyWith({bool? favorite, int? lastPage, String? status, String? note, List<String>? tags, String? path}) => PdfDocumentModel(
        name: name,
        path: path ?? this.path,
        pages: pages,
        updated: updated,
        favorite: favorite ?? this.favorite,
        lastPage: lastPage ?? this.lastPage,
        status: status ?? this.status,
        note: note ?? this.note,
        tags: tags ?? this.tags,
      );
}

class LibraryWorkspace {
  const LibraryWorkspace({required this.name, required this.createdAt});

  final String name;
  final String createdAt;
}

class ContentMatch {
  const ContentMatch({required this.path, required this.pageNumber, required this.snippet});

  final String path;
  final int pageNumber;
  final String snippet;
}

class ChatCitation {
  const ChatCitation({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

class ChatConversation {
  ChatConversation({
    required this.id,
    required this.title,
    required this.documentPath,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  String title;
  final String documentPath;
  final List<ChatMessage> messages;
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
    this.citations = const [],
    this.id = '',
  });

  final String id;
  final String text;
  final bool isUser;
  final String? citation;
  final List<ChatCitation> citations;
}

class AiToolResult {
  const AiToolResult({
    required this.operation,
    required this.title,
    required this.content,
    this.items = const [],
  });

  final String operation;
  final String title;
  final String content;
  final List<Map<String, dynamic>> items;

  factory AiToolResult.fromJson(Map<dynamic, dynamic> json) => AiToolResult(
        operation: json['operation'] as String? ?? '',
        title: json['title'] as String? ?? 'AI result',
        content: json['content'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList(),
      );
}

class ToolDefinition {
  const ToolDefinition(this.label, this.description, this.icon, this.color);

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}
