// import 'dart:async';
// import 'dart:io';
// import 'dart:convert';

// import 'package:flutter/cupertino.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// import '../../provider/types/relayer_request.dart';
// import '../../provider/types/relayer_response.dart';
// import '../../provider/types/rpc_response.dart';
// import '../../relayer/url_builder.dart';

// part '../provider/types/inbound_message.dart';

// final webViewKey = GlobalKey<WebViewRelayerState>();

// class WebViewRelayer extends StatefulWidget {
//   final Map<int, Completer> _messageHandlers = {};
//   final List<RelayerRequest> _queue = [];

//   bool _overlayReady = false;
//   bool _isOverlayVisible = false;

//   late WebViewController webViewCtrl;

//   void enqueue(
//       {required RelayerRequest relayerRequest,
//       required int id,
//       required Completer completer}) {
//     _queue.add(relayerRequest);
//     _messageHandlers[id] = completer;
//     _dequeue();
//   }

//   void _dequeue() {
//     if (_queue.isNotEmpty && _overlayReady) {
//       var message = _queue.removeAt(0);
//       var messageMap = message.toJson((value) => value);
//       // debugPrint(messageMap.toString());
//       //double encoding results in extra backslash. Remove them
//       String jsonString =
//           json.encode({"data": messageMap}).replaceAll("\\", "");
//       // debugPrint("Send Message ===> \n $jsonString");


//       webViewKey.currentState?.runScript(jsonString);

//       // Recursively dequeue till queue is Empty
//       _dequeue();
//     }
//   }

//   void showOverlay() {
//     _isOverlayVisible = true;
//   }

//   void hideOverlay() {
//     _isOverlayVisible = false;
//   }

//   void handleResponse(JavaScriptMessage message) {
//     try {
//       var json = message.decode();

//       // parse JSON into General RelayerResponse to fetch id first, result will handled in the function interface
//       RelayerResponse relayerResponse =
//           RelayerResponse<dynamic>.fromJson(json, (result) => result);
//       MagicRPCResponse rpcResponse = relayerResponse.response;

//       var result = rpcResponse.result;
//       var id = rpcResponse.id;

//       // get callbacks in the handlers map
//       var completer = _messageHandlers[id];

//       // Surface the Raw JavascriptMessage back to the function call so it can converted back to Result type
//       // Only decode when result is not null, so the result is not null
//       if (result != null) {
//         completer!.complete(message);
//       }

//       if (rpcResponse.error != null) {
//         completer!.completeError(rpcResponse.error!.toJson());
//       }
//     } catch (err) {
//       //Todo Add internal error collector
//       debugPrint("parse Error ${err.toString()}");
//     }
//   }

//   WebViewRelayer({Key? key}) : super(key: key);

//   @override
//   WebViewRelayerState createState() => WebViewRelayerState();
// }

// class WebViewRelayerState extends State<WebViewRelayer> {
//   @override
//   void initState() {
//     super.initState();
//     // Enable hybrid composition.
//     // if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();

//     late final params = PlatformWebViewControllerCreationParams();
//     late final controller =
//         WebViewController.fromPlatformCreationParams(params);

//     // String url = await URLBuilder.instance.url;

//     controller
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..addJavaScriptChannel('magicFlutter', onMessageReceived: onMessageReceived);
//     // ..loadRequest(Uri.parse(url));

//     _controller = controller;

//     URLBuilder.instance.url
//         .then((value) => _controller.loadRequest(Uri.parse(value)));
//   }

//   @override
//   Widget build(BuildContext context) {
//     void onMessageReceived(JavaScriptMessage message) {
//       // debugPrint("Received message <=== \n ${message.message}");

//       if (message.getMsgType() ==
//           InboundMessageType.MAGIC_OVERLAY_READY.toShortString()) {
//         widget._overlayReady = true;
//         widget._dequeue();
//       } else if (message.getMsgType() ==
//           InboundMessageType.MAGIC_SHOW_OVERLAY.toShortString()) {
//         setState(() {
//           // setState can only be accessed in this context
//           widget._isOverlayVisible = true;
//         });
//       } else if (message.getMsgType() ==
//           InboundMessageType.MAGIC_HIDE_OVERLAY.toShortString()) {
//         setState(() {
//           widget._isOverlayVisible = false;
//         });
//       } else if (message.getMsgType() ==
//           InboundMessageType.MAGIC_HANDLE_EVENT.toShortString()) {
//         //Todo PromiseEvent
//       } else if (message.getMsgType() ==
//           InboundMessageType.MAGIC_HANDLE_RESPONSE.toShortString()) {
//         widget.handleResponse(message);
//       }
//     }

//     return Visibility(
//         visible: widget._isOverlayVisible,
//         maintainState: true,
//         child: WebView(
//           debuggingEnabled: true,
//           javascriptMode: JavascriptMode.unrestricted,
//           javascriptChannels: {
//             JavascriptChannel(
//                 name: 'magicFlutter', onMessageReceived: onMessageReceived)
//           },
//           onWebViewCreated: (WebViewController w) async {
//             widget.webViewCtrl = w;
//             String url = await URLBuilder.instance.url;
//             w.loadUrl(url);
//           },
//         ));
//   }
// }

// /// Extended utilities to help to decode JS Message
// extension MessageType on JavascriptMessage {
//   Map<String, dynamic> decode() {
//     return json.decode(message);
//   }

//   String getMsgType() {
//     var json = decode();
//     var msgType = json['msgType'].split('-').first;
//     return msgType;
//   }
// }


import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:magic_sdk/relayer/url_builder.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../provider/types/relayer_request.dart';
import '../../provider/types/relayer_response.dart';
import '../../provider/types/rpc_response.dart';

part '../provider/types/inbound_message.dart';

final webViewKey = GlobalKey<WebViewRelayerState>();

class WebViewRelayer extends StatefulWidget {
  WebViewRelayer() : super(key: webViewKey);

  final Map<int, Completer> _messageHandlers = {};
  final List<RelayerRequest> _queue = [];

  bool _overlayReady = false;
  bool _isOverlayVisible = false;

  void enqueue(
      {required RelayerRequest relayerRequest,
      required int id,
      required Completer completer}) {
    _queue.add(relayerRequest);
    _messageHandlers[id] = completer;
    _dequeue();
  }

  void _dequeue() {
    if (_queue.isNotEmpty && _overlayReady) {
      var message = _queue.removeAt(0);
      var messageMap = message.toJson((value) => value);
      // debugPrint(messageMap.toString());
      //double encoding results in extra backslash. Remove them
      String jsonString =
          json.encode({"data": messageMap}).replaceAll("\\", "");
      // debugPrint("Send Message ===> \n $jsonString");
      //
      // webViewCtrl.runJavaScript(
      //     "window.dispatchEvent(new MessageEvent('message', $jsonString));");

      webViewKey.currentState?.runScript(jsonString);
      // Recursively dequeue till queue is Empty
      _dequeue();
    }
  }

  void showOverlay() {
    _isOverlayVisible = true;
  }

  void hideOverlay() {
    _isOverlayVisible = false;
  }

  void handleResponse(JavaScriptMessage message) {
    try {
      var json = message.decode();

      // parse JSON into General RelayerResponse to fetch id first, result will handled in the function interface
      RelayerResponse relayerResponse =
          RelayerResponse<dynamic>.fromJson(json, (result) => result);
      MagicRPCResponse rpcResponse = relayerResponse.response;

      var result = rpcResponse.result;
      var id = rpcResponse.id;

      // get callbacks in the handlers map
      var completer = _messageHandlers[id];

      // Surface the Raw JavascriptMessage back to the function call so it can converted back to Result type
      // Only decode when result is not null, so the result is not null
      if (result != null) {
        completer!.complete(message);
      }

      if (rpcResponse.error != null) {
        completer!.completeError(rpcResponse.error!.toJson());
      }
    } catch (err) {
      //Todo Add internal error collector
      debugPrint("parse Error ${err.toString()}");
    }
  }

  @override
  WebViewRelayerState createState() => WebViewRelayerState();
}

class WebViewRelayerState extends State<WebViewRelayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    // if (!kIsWeb && Platform.isAndroid)
    //   WebView.platform = SurfaceAndroidWebView();

    late final params = PlatformWebViewControllerCreationParams();
    late final controller =
        WebViewController.fromPlatformCreationParams(params);

    // String url = await URLBuilder.instance.url;

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('magicFlutter',
          onMessageReceived: onMessageReceived);
    // ..loadRequest(Uri.parse(url));
    _controller = controller;

    URLBuilder.instance.url
        .then((value) => _controller.loadRequest(Uri.parse(value)));
  }

  void onMessageReceived(JavaScriptMessage message) {
    // debugPrint("Received message <=== \n ${message.message}");

    if (message.getMsgType() ==
        InboundMessageType.MAGIC_OVERLAY_READY.toShortString()) {
      widget._overlayReady = true;
      widget._dequeue();
    } else if (message.getMsgType() ==
        InboundMessageType.MAGIC_SHOW_OVERLAY.toShortString()) {
      setState(() {
        // setState can only be accessed in this context
        widget._isOverlayVisible = true;
      });
    } else if (message.getMsgType() ==
        InboundMessageType.MAGIC_HIDE_OVERLAY.toShortString()) {
      setState(() {
        widget._isOverlayVisible = false;
      });
    } else if (message.getMsgType() ==
        InboundMessageType.MAGIC_HANDLE_EVENT.toShortString()) {
      //Todo PromiseEvent
    } else if (message.getMsgType() ==
        InboundMessageType.MAGIC_HANDLE_RESPONSE.toShortString()) {
      widget.handleResponse(message);
    }
  }

  void runScript(String jsonString) {
    _controller.runJavaScript(
        "window.dispatchEvent(new MessageEvent('message', $jsonString));");
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: widget._isOverlayVisible,
        maintainState: true,
        child: WebViewWidget(
          controller: _controller,
        )

        // WebView(
        //   debuggingEnabled: true,
        //   javascriptMode: JavaScriptMode.unrestricted,
        //   javascriptChannels: {
        //     JavascriptChannel(
        //         name: 'magicFlutter', onMessageReceived: onMessageReceived)
        //   },
        //   onWebViewCreated: (WebViewController w) async {
        //     widget.webViewCtrl = w;
        //     String url = await URLBuilder.instance.url;
        //     w.loadUrl(url);
        //   },
        // )

        );
  }
}

/// Extended utilities to help to decode JS Message
extension MessageType on JavaScriptMessage {
  Map<String, dynamic> decode() {
    return json.decode(message);
  }

  String getMsgType() {
    var json = decode();
    var msgType = json['msgType'].split('-').first;
    return msgType;
  }
}
