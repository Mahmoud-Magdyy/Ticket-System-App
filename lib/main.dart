import 'dart:io';
import 'package:http/io_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CookieManager.instance().setCookie(
    url: WebUri('https://cksales.tmtegyptgroup.com/CK-Ticket/'),
    name: 'test',
    value: 'test',
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  PullToRefreshController? _pullToRefreshController;
  bool _isLoading = true;
  bool _tokenSent = false; // عشان منبعتش التوكن أكتر من مرة لنفس الجلسة

  final String _targetUrl = 'https://cksales.tmtegyptgroup.com/CK-Ticket/';
  final String _serverBaseUrl = 'https://cksales.tmtegyptgroup.com/CK-Ticket';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

 @override
void initState() {
  super.initState();
  
  // ✅ إعداد Pull-to-Refresh
  _pullToRefreshController = PullToRefreshController(
    settings: PullToRefreshSettings(
      color: Colors.blue, // لون دائرة التحميل
      backgroundColor: Colors.white, // لون الخلفية
    ),
    onRefresh: () async {
      if (webViewController != null) {
        await webViewController!.reload();
      }
    },
  );
  FirebaseMessaging.instance.requestPermission();
  _initNotifications();
}

Future<void> _initNotifications() async {
  await _createNotificationChannel(); // ✅ ننتظرها تخلص الأول
  _setupForegroundNotifications();
  _setupNotificationClickHandling();
}

  void _setupNotificationClickHandling() {
  // لو التطبيق كان مقفول تمامًا وفتح بسبب ضغط الإشعار
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    debugPrint('🔍 getInitialMessage تم استدعاؤها');
    if (message != null) {
      debugPrint('📬 Initial message data: ${message.data}');
      _navigateToTarget(message.data);
    } else {
      debugPrint('⚠️ getInitialMessage رجعت null');
    }
  });

  // لو التطبيق كان في الخلفية (Minimized) وفتح بسبب ضغط الإشعار
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📬 onMessageOpenedApp - data: ${message.data}');
    _navigateToTarget(message.data);
  });
}

void _navigateToTarget(Map<String, dynamic> data) {
  debugPrint('🔍 _navigateToTarget استُدعيت بالبيانات: $data');
  final targetUrl = data['target_url'];
  debugPrint('🔍 targetUrl = $targetUrl');
  debugPrint('🔍 webViewController = ${webViewController != null ? "موجود" : "NULL!"}');
  
  if (targetUrl != null &&
      targetUrl.isNotEmpty &&
      webViewController != null) {
    final fullUrl = '$_serverBaseUrl$targetUrl';
    debugPrint('🎯 التوجيه لصفحة التذكرة: $fullUrl');
    webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(fullUrl)));
  } else {
    debugPrint('❌ لم يتم التوجيه - شرط لم يتحقق');
  }
}
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'هذه القناة تستخدم للإشعارات المهمة',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: null,
      
    );
    await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  }

  void _setupForegroundNotifications() {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // لو حصل تخزين للـ payload وقت الإشعار، تقدر تستخدمه هنا
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message: ${message.notification?.title}');
      _localNotifications.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // ✅ اسم قناة جديد
            'High Importance Notifications',
            channelDescription: 'هذه القناة تستخدم للإشعارات المهمة',
            importance: Importance.max, // ✅ من high لـ max
            priority: Priority.max, // ✅ من high لـ max
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true, 
            audioAttributesUsage: AudioAttributesUsage.notification, // 👈 بيحدد للنظام إن ده صوت إشعار
            category: AndroidNotificationCategory.call, // ✅ جديد، بيعامل الإشعار كأنه مكالمة واردة (أقوى أولوية ممكنة)
           visibility: NotificationVisibility.public,// ✅ جديد: يخلي الإشعار يظهر فوق أي حاجة
           
          ),
        ),
        payload: message.data['target_url'],
      );
    });
  }

  // بيتنده لما يحصل نجاح لوجين (وصول لصفحة Home/Home)
  Future<void> _onLoginDetected() async {
    if (_tokenSent) return; // منعمهاش أكتر من مرة
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // 1. هات الـ Cookie اللي فيه اسم المستخدم
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(_serverBaseUrl),
      );
      debugPrint('🍪 تفاصيل الكوكيز الكاملة:');
      for (var c in cookies) {
        debugPrint('   الاسم: ${c.name}');
        debugPrint('   تاريخ الانتهاء: ${c.expiresDate}');
        debugPrint('   isSessionOnly: ${c.isSessionOnly}');
        debugPrint('   ---');
      }

      final usernameCookie = cookies.firstWhere(
        (c) => c.name == 'savedUsername',
        orElse: () => Cookie(name: '', value: ''),
      );

      if (usernameCookie.value.isEmpty) {
        debugPrint('⚠️ لم يتم العثور على savedUsername cookie');
        return;
      }

      final username = usernameCookie.value;
      debugPrint('👤 Username من الكوكي: $username');

      // 2. هات الـ FCM Token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint('⚠️ لم يتم الحصول على FCM Token');
        return;
      }
      debugPrint('🔑 FCM Token: $fcmToken');
      http.Client _createInsecureClient() {
        final httpClient = HttpClient();
        httpClient.badCertificateCallback = (cert, host, port) => true;
        return IOClient(httpClient);
      }

      // 3. ابعتهم للسيرفر
      final client = _createInsecureClient();
      final response = await client.post(
        Uri.parse('$_serverBaseUrl/api/notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'token': fcmToken}),
      );
      client.close();

      if (response.statusCode == 200) {
        debugPrint('✅ تم تسجيل الـ FCM Token بنجاح للسيرفر');
        _tokenSent = true;
      } else {
        debugPrint(
          '🔴 فشل تسجيل الـ Token: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('🔴 خطأ أثناء إرسال الـ Token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_targetUrl)),
                pullToRefreshController: _pullToRefreshController,
                initialSettings: InAppWebViewSettings(
                  incognito: false,
                  javaScriptEnabled: true,
                  allowContentAccess: true,
                  allowFileAccess: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useShouldOverrideUrlLoading: true,
                  cacheEnabled: true,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                  supportZoom: true,
                  useHybridComposition: true,
                  thirdPartyCookiesEnabled: true,
                  domStorageEnabled: true, // ✅ جديد
                  databaseEnabled: true,
                  clearCache: false, // 👈 ما تمسحش الكاش كل مرة

                ),
                onWebViewCreated: (controller) {
                  debugPrint('🟣 onWebViewCreated');
                  webViewController = controller;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url.toString();
                  debugPrint('🧭 Navigating to: $url');

                  // لو الرابط بيدل على نجاح تسجيل الدخول
                  if (!url.contains('/Login/Login') &&
                      !url.contains('/login/login')) {
                    _onLoginDetected();
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  debugPrint(
                    '🔵 SSL Challenge received for: ${challenge.protectionSpace.host}',
                  );
                  return ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.PROCEED,
                  );
                },
                onLoadStart: (controller, url) {
                  debugPrint('🟡 Load START: $url');
                },
                onLoadStop: (controller, url) async {
                  debugPrint('🟢 Load STOP: $url');
                   _pullToRefreshController?.endRefreshing(); 
                },
                onReceivedError: (controller, request, error) {
                  debugPrint(
                    '🔴 WebView Error: ${error.description} - URL: ${request.url}',
                  );
                  _pullToRefreshController?.endRefreshing();
                },
                onProgressChanged: (controller, progress) {
                  debugPrint('📊 Progress: $progress%');
                  setState(() {
                    _isLoading = progress < 100;
                  });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('🖥️ Console: ${consoleMessage.message}');
                },
              ),
            ),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
