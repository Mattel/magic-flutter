import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:magic_sdk/relayer/url_builder.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webviewx/src/utils/webview_flutter_original_utils.dart';
import 'package:webviewx/webviewx.dart';

import '../../provider/types/relayer_request.dart';
import '../../provider/types/relayer_response.dart';
import '../../provider/types/rpc_response.dart';

part '../provider/types/inbound_message.dart';

class WebViewRelayer extends StatefulWidget {
  final Map<int, Completer> _messageHandlers = {};
  final List<RelayerRequest> _queue = [];

  bool _overlayReady = false;
  bool _isOverlayVisible = true;

  late WebViewXController webViewCtrl;

  void enqueue(
      {required RelayerRequest relayerRequest,
      required int id,
      required Completer completer}) {
    _queue.add(relayerRequest);
    _messageHandlers[id] = completer;
    _dequeue();
  }

  void _dequeue() {
    debugPrint(
        'dequeque has elements: ${_queue.isNotEmpty} overlay ready: $_overlayReady');
    if (_queue.isNotEmpty && _overlayReady) {
      var message = _queue.removeAt(0);
      var messageMap = message.toJson((value) => value);
      debugPrint(messageMap.toString());
      //double encoding results in extra backslash. Remove them
      String jsonString =
          json.encode({"data": messageMap}).replaceAll("\\", "");
      // debugPrint("Send Message ===> \n $jsonString");

      webViewCtrl.evalRawJavascript(
          "window.dispatchEvent(new MessageEvent('message', $jsonString));");

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

  void handleResponse(String message) {
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
        completer!.complete(json);
      }

      if (rpcResponse.error != null) {
        completer!.completeError(rpcResponse.error!.toJson());
      }
    } catch (err) {
      //Todo Add internal error collector
      debugPrint("parse Error ${err.toString()}");
    }
  }

  WebViewRelayer({Key? key}) : super(key: key);

  @override
  WebViewRelayerState createState() => WebViewRelayerState();
}

class WebViewRelayerState extends State<WebViewRelayer> {
  bool isCreated = false;
  bool finishedLoading = false;
  @override
  void initState() {
    super.initState();
    // Enable hybrid composition.
    // if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    void onMessageReceived(dynamic msg) {
      debugPrint('onMessageReceived');
      if (!(msg is String)) {
        return;
      }
      debugPrint("Received message <=== \n $msg");
      final message = msg as String;
      final type = message.getType();

      switch (type) {
        case InboundMessageType.MAGIC_OVERLAY_READY:
          debugPrint("onMessageReceived -> MAGIC_OVERLAY_READY");
          widget._overlayReady = true;
          widget._dequeue();
          break;
        case InboundMessageType.MAGIC_SHOW_OVERLAY:
          setState(() {
            // setState can only be accessed in this context
            widget._isOverlayVisible = true;
          });
          break;
        case InboundMessageType.MAGIC_HIDE_OVERLAY:
          setState(() {
            widget._isOverlayVisible = false;
          });
          break;
        case InboundMessageType.MAGIC_HANDLE_EVENT:
          break;
        case InboundMessageType.MAGIC_HANDLE_RESPONSE:
          widget.handleResponse(message);
          break;
      }
    }

    return WebViewX(
      onPageStarted: (src) =>
          debugPrint('A new page has started loading: $src\n'),
      onPageFinished: (src) {
        if (!finishedLoading) {
          finishedLoading = true;
          Future.delayed(const Duration(seconds: 5), () async {
            await widget.webViewCtrl.callJsMethod(
                'magicFlutter', ['{"msgType": "MAGIC_OVERLAY_READY"}']);
          });
        }
        debugPrint('The page has finished loading: $src\n');
      },
      // initialContent: ,
      // debuggingEnabled: true,
      javascriptMode: JavascriptMode.unrestricted,
      // javascriptChannels: {
      //   JavascriptChannel(
      //       name: 'magicFlutter', onMessageReceived: onMessageReceived)
      // },
      dartCallBacks: {
        DartCallback(
          name: 'magicFlutter',
          callBack: (message) => onMessageReceived(message),
        )
      },
      onWebViewCreated: (WebViewXController w) {
        widget.webViewCtrl = w;
        if (!isCreated) {
          isCreated = true;
          _loadInitialContent();
        }
      },
      width: 10,
      height: 10,
    );
  }

  _loadInitialContent() async {
    String url = await URLBuilder.instance.url;

    // widget.webViewCtrl.loadContent(url, SourceType.urlBypass);
    widget.webViewCtrl.loadContent(static_magic_link_content, SourceType.html);
  }

  final static_magic_link_content = '''<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,shrink-to-fit=no">
        <meta name="theme-color" content="#120533">
        <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate"/>
        <meta http-equiv="Pragma" content="no-cache"/>
        <meta http-equiv="Expires" content="0"/>
        <meta name="”robots”" content="”noindex”">
        <link rel="icon" id="favicon">
    </head>
    <body>
        <noscript>Please enable JavaScript to run this application.</noscript>
        <div id="root"></div>
        <script src="/static/js/runtime~main.06152605.js"></script>
        <script src="/static/js/2.a600c0b9.chunk.js"></script>
        <script src="/static/js/main.f6806300.chunk.js"></script>
    </body>
</html>
  ''';
}

/// Extended utilities to help to decode JS Message
extension MessageType on String {
  Map<String, dynamic> decode() {
    return json.decode(this);
  }

  String getMsgType() {
    var json = decode();
    var msgType = json['msgType'].split('-').first;
    return msgType;
  }

  InboundMessageType? getType() {
    final stringType = getMsgType();
    for (final type in InboundMessageType.values) {
      if (type.isEqualTo(stringType)) {
        return type;
      }
    }
    return null;
  }
}

extension InboundMessageTypeExtension on InboundMessageType {
  bool isEqualTo(String stringType) {
    return toShortString() == stringType;
  }
}
