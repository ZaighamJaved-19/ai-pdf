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

  PdfDocumentModel copyWith({bool? favorite}) => PdfDocumentModel(
        name: name,
        path: path,
        pages: pages,
        updated: updated,
        favorite: favorite ?? this.favorite,
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
