import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherHelper {
  static final PusherHelper _instance = PusherHelper._internal();
  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();

  factory PusherHelper() {
    return _instance;
  }

  PusherHelper._internal();

  // initialize pusher
  Future<void> initializePusher({
    required void Function(PusherEvent) onEvent,
    String? authEndpoint,
  }) async {
    try {
      await pusher.init(
        apiKey: PusherConstants.apiKey,
        cluster: PusherConstants.cluster,
        onConnectionStateChange: onConnectionStateChange,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onDecryptionFailure: onDecryptionFailure,
        onMemberAdded: onMemberAdded,
        onMemberRemoved: onMemberRemoved,
        authEndpoint: authEndpoint,
        onAuthorizer: (channelName, socketId, options) => generatedAuthorizer(
            channelName, socketId, PusherConstants.appSecret),
      );
      log("Pusher initialized", name: 'PusherHelper');
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper');
    }
  }

  Future<Map<String, String>> generatedAuthorizer(
      String channelName, String socketId, String? appSecret) async {
    log('socketId: $socketId, channelName: $channelName, appSecret: $appSecret',
        name: 'PusherHelper testAuthorizer');
    if (appSecret == null) {
      throw Exception("App Secret is required for test authorizer");
    }

    final stringToSign = "$socketId:$channelName";
    final hmacSha256 = Hmac(sha256, utf8.encode(appSecret));
    final signature = hmacSha256.convert(utf8.encode(stringToSign)).toString();
    final auth = "${PusherConstants.apiKey}:$signature";

    return {'auth': auth};
  }

  Future<void> subscribeToChannel(String channelName) async {
    try {
      await pusher.subscribe(channelName: channelName);
      log("Subscribed to channel: $channelName", name: 'PusherHelper');
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper');
    }
  }

  Future<void> unsubscribeFromChannel(String channelName) async {
    try {
      await pusher.unsubscribe(channelName: channelName);
      log("Unsubscribed from channel: $channelName", name: 'PusherHelper');
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper');
    }
  }

  Future<void> connectToPusher() async {
    try {
      await pusher.connect();
      log("Connected to Pusher", name: 'PusherHelper connectToPusher');
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper connectToPusher');
    }
  }

  Future<void> disconnectFromPusher() async {
    try {
      await pusher.disconnect();
      log("Disconnected from Pusher",
          name: 'PusherHelper disconnectFromPusher');
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper disconnectFromPusher');
    }
  }

  Future<void> triggerEvent(
      String channelName, String eventName, dynamic data) async {
    log("Attempting to trigger event", name: 'PusherHelper triggerEvent');
    log("Channel: $channelName, Event: $eventName, Data: $data",
        name: 'PusherHelper triggerEvent');

    try {
      await pusher.trigger(PusherEvent(
          channelName: channelName, eventName: eventName, data: data));
      log("Event triggered successfully on channel: $channelName, Event: $eventName",
          name: 'PusherHelper triggerEvent');
    } catch (e) {
      log("ERROR while triggering event on channel: $channelName, Event: $eventName, Error: $e",
          name: 'PusherHelper triggerEvent', error: e);
    }
  }

  Future<PusherChannel?> getChannel(String channelName) async {
    try {
      return pusher.getChannel(channelName);
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper getChannel');
      return Future.error(e);
    }
  }

  Future<void> getSocketInfo() async {
    try {
      final socketId = await pusher.getSocketId();
      log("Socket ID: $socketId", name: 'PusherHelper getSocketInfo');
    } catch (e) {
      log("ERROR: $e", name: 'PusherHelper getSocketInfo');
    }
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    log("onSubscriptionSucceeded: $channelName data: $data",
        name: "pusher onSubscriptionSucceeded");
  }

  void onSubscriptionError(String message, dynamic e) {
    log("onSubscriptionError: $message Exception: $e",
        name: "pusher onSubscriptionError");
  }

  void onDecryptionFailure(String event, String reason) {
    log("onDecryptionFailure: $event reason: $reason",
        name: "pusher onDecryptionFailure");
  }

  void onMemberAdded(String channelName, PusherMember member) {
    log("onMemberAdded: $channelName member: $member",
        name: "pusher onMemberAdded");
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    log("onMemberRemoved: $channelName member: $member",
        name: "pusher onMemberRemoved");
  }

  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    log("Connection: $currentState", name: 'pusher onConnectionStateChange');
  }

  void onError(String message, int? code, dynamic e) {
    log("onError: $message code: $code exception: $e", name: 'pusher onError');
  }
}

class PusherConstants {
  static const String apiKey = 'your_api_key';
  static const String cluster = 'your_cluster';
  static const String appSecret = 'your_app_secret';

  static const String privateChannelName =
      'private-your-channel-name'; //private keyword must be included
  static const String clientEventName =
      'client-your-event-name'; // client keyword must be included
}
