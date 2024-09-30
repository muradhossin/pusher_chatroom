import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:pusher_chatroom/src/helpers/pusher_helper.dart';
import 'package:intl/intl.dart';

class ChatroomScreen extends StatefulWidget {
  const ChatroomScreen({super.key});

  @override
  ChatroomScreenState createState() => ChatroomScreenState();
}

class ChatroomScreenState extends State<ChatroomScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  String? _username;
  String? _channelName;
  String? _eventName;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_username == null || _channelName == null || _eventName == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptForDetails();
      });
    }
  }

  void _promptForDetails() async {
    Map<String, String?> details = await _showDetailsDialog();
    if (details['username'] != null &&
        details['channelName'] != null &&
        details['eventName'] != null) {
      setState(() {
        _username = details['username']!;
        _channelName = "private-${details['channelName']!}";
        _eventName = "client-${details['eventName']!}";
      });
      initializePusher();
    } else {
      _promptForDetails();
    }
  }

  Future<Map<String, String?>> _showDetailsDialog() async {
    TextEditingController nameController = TextEditingController();
    TextEditingController channelController = TextEditingController();
    TextEditingController eventController = TextEditingController();

    return await showDialog<Map<String, String?>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Enter Chat Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Your name'),
                  ),
                  TextField(
                    controller: channelController,
                    decoration: const InputDecoration(
                        hintText: 'Channel name (without private-)'),
                  ),
                  TextField(
                    controller: eventController,
                    decoration: const InputDecoration(
                        hintText: 'Event name (without client-)'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    // Return the map with the input values
                    // if any of the fields are empty, return null
                    if (nameController.text.isEmpty ||
                        channelController.text.isEmpty ||
                        eventController.text.isEmpty) {
                      Navigator.of(context).pop({
                        'username': null,
                        'channelName': null,
                        'eventName': null,
                      });
                    } else {
                      Navigator.of(context).pop({
                        'username': nameController.text,
                        'channelName': channelController.text,
                        'eventName': eventController.text,
                      });
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        ) ??
        {
          'username': null,
          'channelName': null,
          'eventName': null,
        }; // Ensure that the return is always a map, even if the dialog is dismissed.
  }

  Future<void> initializePusher() async {
    void handleEvent(PusherEvent event) {
      log("Received event: $event", name: 'Chatroom _handleEvent');
      if (event.data is String) {
        log("Received message: ${event.data}", name: 'Chatroom _handleEvent');
        try {
          Map<String, dynamic> decryptedData = _decodeMessage(event.data);
          setState(() {
            _messages.add(decryptedData);
            log("Message added to list: $decryptedData",
                name: 'Chatroom _handleEvent');
          });
        } catch (e) {
          log("Error decrypting message: $e",
              name: 'Chatroom _handleEvent', error: e);
        }
      }
    }

    await PusherHelper().initializePusher(onEvent: handleEvent);
    await PusherHelper().connectToPusher();
    await PusherHelper().subscribeToChannel(_channelName!);
  }

  Future<void> _sendMessage() async {
    if (_username == null || _channelName == null || _eventName == null) {
      _promptForDetails();
      return;
    }

    if (_messageController.text.isNotEmpty) {
      log("Sending message: ${_messageController.text}", name: 'Chatroom');

      Map<String, dynamic> messageMap = {
        'username': _username!,
        'message': _messageController.text,
        'timestamp': DateFormat('hh:mm a').format(DateTime.now()),
        'isMe': true,
      };

      String jsonMessage = _encodeMessage(messageMap);

      try {
        await PusherHelper().triggerEvent(
          _channelName!,
          _eventName!,
          jsonMessage,
        );

        log("Message sent: ${_messageController.text}", name: 'Chatroom');
        setState(() {
          _messages.add(messageMap);
          _messageController.clear();
        });
      } catch (e) {
        log("Error sending message: $e", name: 'Chatroom', error: e);
      }
    } else {
      log("Empty message, not sent.", name: 'Chatroom');
    }
  }

  String _encodeMessage(Map<String, dynamic> messageMap) {
    return jsonEncode(messageMap); // Encode to JSON string
  }

  Map<String, dynamic> _decodeMessage(String jsonMessage) {
    Map<String, dynamic> jsonMap = jsonDecode(jsonMessage);
    jsonMap['isMe'] = jsonMap['username'] ==
        _username; // Check if the sender is the current user
    return jsonMap;
  }

  @override
  void dispose() {
    PusherHelper().unsubscribeFromChannel(_channelName!);
    PusherHelper().disconnectFromPusher();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatroom'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(
                    _messages[_messages.length - 1 - index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    bool isMe = message['isMe'] ?? false;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              message['username'] ?? 'Unknown', // Fallback to 'Unknown' if null
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.blueAccent : Colors.grey[300],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(10),
                topRight: const Radius.circular(10),
                bottomLeft:
                    isMe ? const Radius.circular(10) : const Radius.circular(0),
                bottomRight:
                    isMe ? const Radius.circular(0) : const Radius.circular(10),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message['message'] ?? '', // Fallback to empty string if null
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message['timestamp'] ??
                      '', // Fallback to empty string if null
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
