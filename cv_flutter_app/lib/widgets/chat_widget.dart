import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:math' as math;

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isOpen = false;
  final double _maxHeight = 500.0; // Maximum height of the chat window
  final double _minHeight = 160.0; // Minimum height when empty
  final double _messageAreaPadding = 16.0; // Padding around message area
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMessage = message;
    _messageController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(AppConfig.chatEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': userMessage}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({'role': 'assistant', 'content': data['response']});
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content':
                'Sorry, I encountered an error. Please try again. Status: ${response.statusCode}'
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content':
              'Network error: ${e.toString()}. Please check your connection.'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      // Scroll to bottom after new message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  double _calculateChatWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // On larger screens (web/desktop), limit width to 400px
    // On mobile, use 90% of screen width
    return screenWidth > 600 ? 400 : screenWidth * 0.9;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    final chatWidth = _calculateChatWidth(context);
    final screenHeight = media.size.height;
    const double topMargin = 16.0;
    final double bottomPadding =
        isKeyboardVisible ? keyboardHeight + safeBottom : 16.0 + safeBottom;
    final double verticalMargin = topMargin + bottomPadding;

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isOpen)
              Flexible(
                child: SizedBox(
                  width: chatWidth,
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: _minHeight,
                        maxHeight:
                            math.min(_maxHeight, screenHeight - verticalMargin),
                      ),
                      child: Card(
                        margin: const EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          top: 16.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(_messageAreaPadding / 2),
                              child: Text(
                                'Ask me about Mathieu\'s CV',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (_messages.isNotEmpty || _isLoading)
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  itemCount: _messages.length,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  itemBuilder: (context, index) {
                                    final message =
                                        _messages[_messages.length - 1 - index];
                                    return _buildMessageBubble(
                                      message['content']!,
                                      message['role'] == 'user',
                                    );
                                  },
                                ),
                              ),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            Padding(
                              padding: EdgeInsets.all(_messageAreaPadding),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      decoration: const InputDecoration(
                                        hintText: 'Type your question...',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8.0,
                                        ),
                                      ),
                                      onSubmitted: (value) =>
                                          _sendMessage(value),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () =>
                                        _sendMessage(_messageController.text),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _isOpen = !_isOpen;
                    });
                  },
                  child: Icon(_isOpen ? Icons.close : Icons.chat),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                0.6, // Maximum width of 60% of chat width
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: isUser ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: isUser ? Colors.blue[900] : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
