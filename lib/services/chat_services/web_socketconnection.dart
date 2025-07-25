// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:p_chat/global_content/global_varable.dart';
import 'package:p_chat/global_content/snack_bar.dart';
import 'package:p_chat/screens/chat_screen/chat_input.dart';
import 'package:p_chat/screens/chat_screen/chat_view.dart';
import 'package:p_chat/screens/chat_screen/history_view.dart';
import 'package:p_chat/screens/chat_screen/providers.dart';
import 'package:p_chat/services/all_endpoint.dart';
import 'package:p_chat/srorage/pref_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class WebSocketConnectionServices {
  static Future<void> connectWebSocket(
      String pdfId, WidgetRef ref, BuildContext context,
      {required VoidCallback onMessageReceived,
      required Function(Message) addMessageToUi}) async {
    String token = await Pref.getStringValue(tokenKey);
    String _accessToken = token.trim();

    if (ChatProviders.channel != null) {
      debugPrint('Closing existing WebSocket connection...');
      await ChatProviders.channel!.sink.close(1000, 'Reconnecting');
      ChatProviders.channel = null;
    }

    if (_accessToken.isEmpty) {
      LogOutUser.logUserOut(ref, context);
      return;
    }

    try {
      String tokenForWs = _accessToken.startsWith('Bearer ')
          ? _accessToken
          : 'Bearer $_accessToken';

      final wsUrl =
          Uri.parse('$chatWebsocketBaseUrl$pdfId?access_token=$tokenForWs');

      debugPrint('Attempting to connect to WebSocket: $wsUrl');
      debugPrint('Pdf ID : $pdfId');

      ChatProviders.channel = WebSocketChannel.connect(wsUrl);
      await ChatProviders.channel!.ready;

      ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = true;
      debugPrint(
          'Is connected to websocket ${ref.read(ChatProviders.isConnectedToWebSocket)}');

      SnackBarView.showSnackBar(context, 'Connected to chat!');
      debugPrint('Connected to chat');

      String currentStreamingMessage = '';
      Message? currentStreamingMessageObj;

      ChatProviders.channel!.stream.listen(
        (data) {
          debugPrint('Received WebSocket data: $data');
          debugPrint('Pdf ID Save: $pdfId');
          try {
            if (data.toString().contains('"ai_response"')) {
              final List<dynamic> responseList = json.decode(data);
              if (responseList.isNotEmpty) {
                for (var item in responseList) {
                  if (item is Map<String, dynamic>) {
                    String aiResponse = item['ai_response'] ??
                        item['message'] ??
                        item['response'] ??
                        '';

                    String promptFromBackend = '';
                    if (item['prompt'] != null && item['prompt'] is String) {
                      promptFromBackend =
                          _extractPromptFromNestedJson(item['prompt']);
                    }

                    if (aiResponse.isNotEmpty && promptFromBackend.isNotEmpty) {
                      ref
                          .read(pdfHistoryListProvider.notifier)
                          .updateHistoryItem(pdfId, promptFromBackend);
                    }
                  }
                }
              }
              currentStreamingMessage = '';
              currentStreamingMessageObj = null;
            } else {
              if (currentStreamingMessageObj == null) {
                currentStreamingMessage = data.toString();
                currentStreamingMessageObj = Message(
                  text: currentStreamingMessage,
                  date: DateTime.now(),
                  pdfId: pdfId,
                  isSentByMe: false,
                );
                addMessageToUi(currentStreamingMessageObj!);
              } else {
                currentStreamingMessage += data.toString();
                currentStreamingMessageObj = Message(
                  text: currentStreamingMessage,
                  date: currentStreamingMessageObj!.date,
                  pdfId: pdfId,
                  isSentByMe: false,
                );
                ref
                    .read(messagesProvider.notifier)
                    .updateLastMessage(currentStreamingMessageObj!);
              }
            }

            ref.read(ChatProviders.isLoading.notifier).state = false;
            onMessageReceived();
          } catch (e) {
            debugPrint('Error parsing WebSocket response: $e. Raw data: $data');
            final aiMessage = Message(
              text: data.toString(),
              date: DateTime.now(),
              pdfId: pdfId,
              isSentByMe: false,
            );
            addMessageToUi(aiMessage);
            ref.read(ChatProviders.isLoading.notifier).state = false;
            onMessageReceived();
          }
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = false;
          ref.read(ChatProviders.isLoading.notifier).state = false;
          SnackBarView.showSnackBar(context, 'Chat disconnected.');
          currentStreamingMessage = '';
          currentStreamingMessageObj = null;
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = false;
          ref.read(ChatProviders.isLoading.notifier).state = false;
          SnackBarView.showSnackBar(context, 'Chat error: $error');
          currentStreamingMessage = '';
          currentStreamingMessageObj = null;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
      ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = false;
      ref.read(ChatProviders.isLoading.notifier).state = false;
      debugPrint(
          '2 is connected to websocket ${ref.read(ChatProviders.isConnectedToWebSocket)}');
    }
  }

  static void sendMessage(
      String messageText, String pdfId, WidgetRef ref, BuildContext context) {
    if (ChatProviders.channel == null ||
        !ref.read(ChatProviders.isConnectedToWebSocket)) {
      debugPrint('WebSocket not connected. Cannot send message.');
      SnackBarView.showSnackBar(context,
          'WebSocket not connected. Please ensure a PDF is uploaded and connection is active.');
      return;
    }

    try {
      final messageData = json.encode({
        'prompt': messageText,
      });

      debugPrint('Sending message: $messageData');
      ChatProviders.channel!.sink.add(messageData);
    } catch (e) {
      debugPrint('Error sending message: $e');
      SnackBarView.showSnackBar(context, 'Error sending message: $e');
    }
  }

  static Future<void> initConnectWebSocket(
      WidgetRef ref, BuildContext context, String pdfId,
      {required VoidCallback onScrollToBottom}) async {
    String token = await Pref.getStringValue(tokenKey);
    String _accessToken = token.trim();

    ref.read(messagesProvider.notifier).clearMessages();

    String tokenForWs = _accessToken.startsWith('Bearer ')
        ? _accessToken
        : 'Bearer $_accessToken';

    final wsUrl =
        Uri.parse('$chatWebsocketBaseUrl$pdfId?access_token=$tokenForWs');

    debugPrint('Attempting to connect to WebSocket for history: $wsUrl');
    debugPrint('History pdf Id : $pdfId');

    try {
      if (ChatProviders.channel != null) {
        await ChatProviders.channel!.sink
            .close(1000, 'Reconnecting for history');
        ChatProviders.channel = null;
      }

      ChatProviders.channel = WebSocketChannel.connect(wsUrl);
      SnackBarView.showSnackBar(context, 'Connecting to chat history...');
      await ChatProviders.channel!.ready;

      ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = true;
      debugPrint(
          'Is connected to websocket ${ref.read(ChatProviders.isConnectedToWebSocket)}');

      debugPrint('Connected to chat history');
      ref.read(ChatProviders.isLoading.notifier).state = false;
      ref.read(ChatProviders.uploadedPdfId.notifier).state = pdfId;

      String currentStreamingMessage = '';
      Message? currentStreamingMessageObj;

      ChatProviders.channel!.stream.listen(
        (data) {
          debugPrint('Received WebSocket history data: $data');
          try {
            if (data.toString().contains('"ai_response"')) {
              final List<dynamic> responseList = json.decode(data);
              if (responseList.isNotEmpty) {
                responseList.sort((a, b) {
                  final DateTime dateA = DateTime.parse(a['created_at']);
                  final DateTime dateB = DateTime.parse(b['created_at']);
                  return dateA.compareTo(dateB);
                });

                for (var item in responseList) {
                  if (item is Map<String, dynamic>) {
                    String aiResponse = item['ai_response'] ??
                        item['message'] ??
                        item['response'] ??
                        '';
                    String promptQuestion = '';
                    DateTime messageDate = DateTime.now();
                    if (item['created_at'] != null) {
                      messageDate = DateTime.parse(item['created_at']);
                    }

                    if (item['prompt'] != null && item['prompt'] is String) {
                      promptQuestion =
                          _extractPromptFromNestedJson(item['prompt']);
                    }

                    if (promptQuestion.isNotEmpty) {
                      final userMessage = Message(
                        text: promptQuestion,
                        date: messageDate,
                        pdfId: pdfId,
                        isSentByMe: true,
                      );
                      ref
                          .read(messagesProvider.notifier)
                          .addMessage(userMessage);
                      ref
                          .read(pdfHistoryListProvider.notifier)
                          .updateHistoryItem(pdfId, promptQuestion);
                    }

                    if (aiResponse.isNotEmpty) {
                      final aiMessage = Message(
                        text: aiResponse,
                        date: messageDate,
                        pdfId: pdfId,
                        isSentByMe: false,
                      );
                      ref.read(messagesProvider.notifier).addMessage(aiMessage);
                    }
                  }
                }
                onScrollToBottom();
              } else {
                debugPrint('Received empty history list from WebSocket.');
                SnackBarView.showSnackBar(
                    context, 'No previous chats found for this PDF.');
              }
              currentStreamingMessage = '';
              currentStreamingMessageObj = null;
            } else {
              if (currentStreamingMessageObj == null) {
                currentStreamingMessage = data.toString();
                currentStreamingMessageObj = Message(
                  text: currentStreamingMessage,
                  date: DateTime.now(),
                  pdfId: pdfId,
                  isSentByMe: false,
                );
                ref
                    .read(messagesProvider.notifier)
                    .addMessage(currentStreamingMessageObj!);
              } else {
                currentStreamingMessage += data.toString();
                currentStreamingMessageObj = Message(
                  text: currentStreamingMessage,
                  date: currentStreamingMessageObj!.date,
                  pdfId: pdfId,
                  isSentByMe: false,
                );
                ref
                    .read(messagesProvider.notifier)
                    .updateLastMessage(currentStreamingMessageObj!);
              }
              onScrollToBottom();
            }
          } catch (e) {
            debugPrint(
                'Error parsing WebSocket history response: $e. Raw data: $data');
            SnackBarView.showSnackBar(context, 'Error loading chat history.');
          }
          ref.read(ChatProviders.isLoading.notifier).state = false;
        },
        onDone: () {
          debugPrint('WebSocket history connection closed');
          ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = false;
          ref.read(ChatProviders.isLoading.notifier).state = false;
          currentStreamingMessage = '';
          currentStreamingMessageObj = null;
        },
        onError: (error) {
          debugPrint('WebSocket history error: $error');
          ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = false;
          ref.read(ChatProviders.isLoading.notifier).state = false;
          SnackBarView.showSnackBar(context, 'Chat history error: $error');
          currentStreamingMessage = '';
          currentStreamingMessageObj = null;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to connect WebSocket for history: $e');
      ref.read(ChatProviders.isConnectedToWebSocket.notifier).state = false;
      ref.read(ChatProviders.isLoading.notifier).state = false;
    }
  }

  static String _extractPromptFromNestedJson(String jsonString) {
    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      if (decoded.containsKey('prompt') && decoded['prompt'] is String) {
        return decoded['prompt'];
      }
    } catch (e) {
      debugPrint(
          'Could not parse prompt from JSON. Treating as plain string: $jsonString. Error: $e');
    }
    return jsonString;
  }
}
