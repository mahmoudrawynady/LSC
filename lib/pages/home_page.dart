import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/custome_navigation.dart';
import '../widgets/loading_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final GlobalKey _webViewKey = GlobalKey();
  CookieManager _cookieManager = CookieManager.instance();
  Map<String, dynamic> _dataMap = {};
  bool _hasCoockies = false;
  bool _isGuest = true;
  bool _isSendGuestToken = false;
  final _baseUrl = "https://portal.lsc-sa.net";
  final _notificationTokenUrl =
      "api/method/lsc_api.lsc_api.create_notification_token.create_notification_token";

  InAppWebViewSettings _settings = InAppWebViewSettings(
      isInspectable: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      supportMultipleWindows: true,
      supportZoom: false,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  void _changeLoading() {
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    _pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                _webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                _webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await _webViewController?.getUrl()));
              }
            },
          );
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {});
    super.initState();
  }

  void _loadUrl(String url) {
    if (_webViewController != null) {
      _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 25, bottom: 20),
            child: InAppWebView(
              key: _webViewKey,
              initialUrlRequest:
                  URLRequest(url: WebUri("$_baseUrl/dashboard/")),
              initialSettings: _settings,
              gestureRecognizers: null,
              initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(),
                  ios: IOSInAppWebViewOptions(
                    allowsLinkPreview: false,
                  )),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (controller, url) {
                _changeLoading();
              },
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url!;

                if (![
                  "http",
                  "https",
                  "file",
                  "chrome",
                  "data",
                  "javascript",
                  "about"
                ].contains(uri.scheme)) {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (controller, createWindowRequest) async {
                if (createWindowRequest.request.url
                    .toString()
                    .contains("checkout.tap.company")) {
                  return false;
                } else {
                  _showBottomSheet(createWindowRequest.request.url.toString());
                }
                return true;
              },
              onCloseWindow: (controller) {
                Navigator.of(context).pop();
              },
              onLoadStop: (controller, url) async {},
              onReceivedError: (controller, request, error) {
                _pullToRefreshController?.endRefreshing();
              },
              onProgressChanged: (controller, progress) {},
              onUpdateVisitedHistory: (controller, url, androidIsReload) async {
                final currentUrl = (url as Uri).path;
                print(currentUrl);
                await _handleGuestToken(currentUrl);
                await _handleLoggedInUser(currentUrl);
              },
              onConsoleMessage: (controller, consoleMessage) {
                if (consoleMessage.message == 'Window.close') {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          if (_isLoading)
            Container(
                color: Colors.white,
                child: context.loadingWidget(loaderColor: Colors.indigoAccent))
        ],
      ),
    );
  }

  Future<void> _readAnSetCookies() async {
    final cookies = await _cookieManager.getCookies(url: WebUri("$_baseUrl/"));
    if (cookies != null && cookies.length > 0) {
      _hasCoockies = true;
      cookies.forEach((item) {
        _dataMap[item.toMap()['name']] = item.toMap()['value'];
      });
    } else {
      _hasCoockies = false;
    }
  }

  Future<void> _sendTokenForGuest() async {
    final fcm = await FirebaseMessaging.instance.getToken();
    final pref = await SharedPreferences.getInstance();
    var headers = {
      'Authorization': 'token f4b8c41d0178105: 153d93a74dd3b7e',
      'Content-Type': 'application/json',
      'Cookie':
          'full_name=Guest; sid=Guest; system_user=no; user_id=Guest; user_image='
    };
    var request =
        http.Request('POST', Uri.parse('$_baseUrl/$_notificationTokenUrl'));
    request.body = json.encode({
      "token": "$fcm",
      "user": "Guest",
      "device_type": Platform.isIOS ? "IOS" : "Android"
    });
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    if (response.statusCode == 200) {
    } else {}
  }

  Future<void> _sendTokenForLoggedInUser() async {
    final fcm = await FirebaseMessaging.instance.getToken();
    var headers = {
      'Authorization': 'token f4b8c41d0178105: 153d93a74dd3b7e',
      'Content-Type': 'application/json',
    };
    var request =
        http.Request('POST', Uri.parse('$_baseUrl/$_notificationTokenUrl'));
    request.body = json.encode({
      "token": "$fcm",
      "device_type": Platform.isIOS ? "IOS" : "Android",
      "user": "${Uri.decodeFull(_dataMap['user_id'])}"
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      SharedPreferences pref = await SharedPreferences.getInstance();

      pref.setBool("isGuestTokenAdded", true);
    } else {}
  }

  Future<void> _handleGuestToken(String url) async {
    if (_isInLoginPage(url)) {
      await _readAnSetCookies();
      SharedPreferences pref = await SharedPreferences.getInstance();
      if (_dataMap != null && _dataMap['sid'] == "Guest") {
        pref.setBool("isGuestTokenAdded", false);
      }

      if (_hasCoockies && _dataMap != null && _dataMap['sid'] == "Guest") {
        print("sent guest token");

        CustomNavigator.userId = "GUEST";
        await _sendTokenForGuest();
      }
    }
  }

  bool _isInLoginPage(String url) {
    return url == "/dashboard/";
  }

  Set<Factory<OneSequenceGestureRecognizer>> _getGestureRecognizers() {
    return {
      (Factory(() => EagerGestureRecognizer())),
    };
  }

  _changeGuestData(String url) {
    if (url.contains("/home")) {
      _isGuest = false;
    }
  }

  Future<void> _handleLoggedInUser(String url) async {
    if (url.contains("/home")) {
      SharedPreferences pref = await SharedPreferences.getInstance();
      final isGuestTokenAdded = pref.getBool("isGuestTokenAdded") ?? false;
      print("is guest added ${isGuestTokenAdded}");
      await _readAnSetCookies();
      if (_hasCoockies &&
          _dataMap != null &&
          _dataMap['sid'] != "Guest" &&
          !isGuestTokenAdded) {
        CustomNavigator.userId = '';
        _changeGuestData(url);
        print("sent logged in user token");
        await _sendTokenForLoggedInUser();
      }
    }
  }

  void _showBottomSheet(String url) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Makes it full-screen
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.9, // Adjust the height as needed
            child: Scaffold(
              body: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(''),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context); // Close the bottom sheet
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: InAppWebView(
                    gestureRecognizers: _getGestureRecognizers(),
                    onCloseWindow: (controller) {
                      print("window closed");
                      Navigator.of(context).pop();
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(
                          "console message internal: ${consoleMessage.message}");
                      if (consoleMessage.message == 'Window.close') {
                        Navigator.of(context).pop();
                      }
                    },
                    initialUrlRequest:
                        URLRequest(url: WebUri.uri(Uri.parse(url))),
                  ),
                )
              ]),
            ),
          );
        });
  }
}
