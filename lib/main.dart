import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'widgets/skeleton_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge system UI styling matching Mother's Hut brand
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MothersHutApp());
}

class MothersHutApp extends StatelessWidget {
  const MothersHutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Mother's Hut",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B4513)),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;

  // Native Android MethodChannel for permissions and system settings
  static const MethodChannel _nativeChannel =
      MethodChannel('com.motherhut.mothers_hut_app/permissions');

  // Static constants for high-speed, zero-allocation intent routing
  static const Set<String> _deviceSchemes = {'tel', 'mailto', 'sms', 'geo'};
  static const Set<String> _upiSchemes = {
    'upi',
    'paytmmp',
    'phonepe',
    'tez',
    'gpay',
  };
  static const List<String> _chatHosts = ['wa.me', 'whatsapp.com'];
  static const List<String> _reviewHosts = [
    'g.page',
    'search.google.com',
    'business.google.com',
    'maps.google.',
    'goo.gl',
    'maps.app.goo.gl',
  ];
  static const List<String> _mapHosts = [
    'maps.google.',
    'goo.gl',
    'maps.app.goo.gl',
  ];
  static const List<String> _socialHosts = [
    'instagram.com',
    'facebook.com',
    'youtube.com',
    'youtu.be',
    'twitter.com',
    'x.com',
  ];

  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isInitialLoadNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hasErrorNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRetryingNotifier = ValueNotifier<bool>(false);

  DateTime? _lastBackPressed;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Mother's Hut official web portal
  final String websiteUrl = 'https://mothershut.com';

  @override
  void initState() {
    super.initState();
    initializeWebView();
    _checkInitialConnectivityAndLoad();
    _initConnectivityListener();
    _requestInitialAppPermissions();
  }

  /// Request all runtime permissions (Location, Camera, Microphone, Storage/Media, Notifications) on cold start
  Future<void> _requestInitialAppPermissions() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      await _requestAllPermissions();
    }
  }

  /// Native bulk permission requester via Kotlin MethodChannel
  Future<bool> _requestAllPermissions() async {
    try {
      final bool? granted = await _nativeChannel.invokeMethod<bool>(
        'requestAllAppPermissions',
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting all permissions: $e');
      return false;
    }
  }

  /// Native location permission requester via Kotlin MethodChannel
  Future<bool> _requestLocationPermission() async {
    try {
      final bool? granted = await _nativeChannel.invokeMethod<bool>(
        'requestLocationPermission',
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  /// Open Android Wi-Fi / Wireless Settings directly so user can enable internet with 1 tap
  Future<void> _openWirelessSettings() async {
    try {
      await _nativeChannel.invokeMethod('openWirelessSettings');
    } catch (e) {
      debugPrint('Error opening wireless settings: $e');
    }
  }

  /// Proactively inspect network connectivity on startup before loading
  Future<void> _checkInitialConnectivityAndLoad() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected) {
        hasErrorNotifier.value = true;
        isLoadingNotifier.value = false;
        if (isInitialLoadNotifier.value) {
          isInitialLoadNotifier.value = false;
        }
      } else {
        controller.loadRequest(Uri.parse(websiteUrl));
      }
    } catch (e) {
      controller.loadRequest(Uri.parse(websiteUrl));
    }
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isConnected = results.any(
        (result) => result != ConnectivityResult.none,
      );

      // Auto-recover when connectivity is restored
      if (isConnected && hasErrorNotifier.value) {
        retryLoading();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    progressNotifier.dispose();
    isLoadingNotifier.dispose();
    isInitialLoadNotifier.dispose();
    hasErrorNotifier.dispose();
    isRetryingNotifier.dispose();
    super.dispose();
  }

  void initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'MothersHutLocationBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'requestLocation') {
            _requestLocationPermission();
          }
        },
      )
      ..addJavaScriptChannel(
        'MothersHutClipboardBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: message.message));
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            progressNotifier.value = value;
            if (value >= 100 && isLoadingNotifier.value) {
              isLoadingNotifier.value = false;
            }
          },

          onPageStarted: (url) {
            debugPrint("Mother's Hut onPageStarted: $url");
            progressNotifier.value = 0;
            isLoadingNotifier.value = true;
            hasErrorNotifier.value = false;
          },

          onPageFinished: (url) {
            debugPrint("Mother's Hut onPageFinished: $url");
            progressNotifier.value = 100;
            isLoadingNotifier.value = false;
            hasErrorNotifier.value = false;
            if (isInitialLoadNotifier.value) {
              isInitialLoadNotifier.value = false;
            }

            // Bridge target="_blank" and window.open for reliable redirects and payment handling
            _injectWindowBridge();
          },

          onWebResourceError: (error) {
            debugPrint(
              "Mother's Hut onWebResourceError: [${error.errorCode}] ${error.description} (isForMainFrame: ${error.isForMainFrame})",
            );

            // Catch network disconnects, DNS resolution errors, host lookup, or main frame failures
            final description = error.description.toLowerCase();
            final isNetworkError =
                error.errorCode == -2 || // ERROR_HOST_LOOKUP
                error.errorCode == -6 || // ERROR_CONNECT
                error.errorCode == -8 || // ERROR_TIMEOUT
                error.errorCode == -1 || // ERROR_UNKNOWN
                description.contains('net::err_internet_disconnected') ||
                description.contains('net::err_name_not_resolved') ||
                description.contains('net::err_connection_refused') ||
                description.contains('net::err_address_unreachable');

            if (error.isForMainFrame == true || isNetworkError) {
              isLoadingNotifier.value = false;
              hasErrorNotifier.value = true;
            }
          },

          onNavigationRequest: _handleNavigationRequest,
        ),
      );

    _configurePlatformCapabilities();
  }

  void _configurePlatformCapabilities() {
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      // Enable WebContents debugging in debug mode
      if (kDebugMode) {
        AndroidWebViewController.enableDebugging(true);
      }

      // Smooth scrolling optimizations: Disable native scrollbars and allow mixed assets
      androidController.setVerticalScrollBarEnabled(false);
      androidController.setHorizontalScrollBarEnabled(false);
      androidController.setMixedContentMode(MixedContentMode.alwaysAllow);

      // Geolocation permissions callback: Auto-allow for Mother's Hut portal
      androidController.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async => const GeolocationPermissionsResponse(
          allow: true,
          retain: true,
        ),
      );

      // Auto-grant protected web resource permissions (camera, microphone)
      androidController.setOnPlatformPermissionRequest(
        (request) => request.grant(),
      );

      // Media playback without requiring physical gesture
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _injectWindowBridge() {
    controller.runJavaScript('''
      (function() {
        if (window.__mhBridgeInjected) return;
        window.__mhBridgeInjected = true;

        // Force native GPU-accelerated touch momentum scrolling and disable rubber-banding conflicts
        var style = document.createElement('style');
        style.innerHTML = `
          * {
            -webkit-tap-highlight-color: transparent !important;
          }
          html, body {
            -webkit-overflow-scrolling: touch !important;
            overscroll-behavior-y: none !important;
          }
        `;
        document.head.appendChild(style);

        // Intercept geolocation requests from web scripts / map auto-locate
        if (navigator.geolocation && !window.__mhGeoHooked) {
          window.__mhGeoHooked = true;
          var origGeo = navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);
          navigator.geolocation.getCurrentPosition = function(success, error, options) {
            try {
              if (window.MothersHutLocationBridge) {
                window.MothersHutLocationBridge.postMessage('requestLocation');
              }
            } catch(e) {}
            origGeo(success, error, options);
          };
        }

        // Bridge clipboard writeText to native Flutter Clipboard for 100% reliable copying
        if (navigator.clipboard && !window.__mhClipHooked) {
          window.__mhClipHooked = true;
          var origClip = navigator.clipboard.writeText.bind(navigator.clipboard);
          navigator.clipboard.writeText = function(text) {
            try {
              if (window.MothersHutClipboardBridge) {
                window.MothersHutClipboardBridge.postMessage(text);
              }
            } catch(e) {}
            return origClip(text);
          };
        }

        // Redirect window.open to location.href for Flutter intent interception
        window.open = function(url) {
          if (url) {
            window.location.href = url;
          }
          return window;
        };

        // Event delegation: Intercept target="_blank" links dynamically with 0% CPU overhead
        document.addEventListener('click', function(e) {
          var target = e.target;
          while (target && target.tagName !== 'A') {
            target = target.parentElement;
          }
          if (target && target.tagName === 'A') {
            if (target.getAttribute('target') === '_blank') {
              target.setAttribute('target', '_self');
            }
          }
        }, true);
      })();
    ''').catchError((e) {
      debugPrint('Error injecting window bridge: $e');
    });
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    // 0. FAST PATH: Instant internal portal dispatch (0ms delay)
    if (host == 'mothershut.com' || host.endsWith('.mothershut.com')) {
      return NavigationDecision.navigate;
    }

    // 1. Direct device schemes: Phone call, Email, SMS, Geolocation
    if (_deviceSchemes.contains(scheme)) {
      _launchExternalUrl(uri, 'Device Tool');
      return NavigationDecision.prevent;
    }

    // 2. UPI & Payment applications with graceful fallback
    if (_upiSchemes.contains(scheme)) {
      _launchUpiPayment(uri);
      return NavigationDecision.prevent;
    }

    // 3. WhatsApp (Direct app or wa.me links)
    if (scheme == 'whatsapp' || _chatHosts.any((h) => host.contains(h))) {
      _launchExternalUrl(uri, 'WhatsApp', mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }

    // 4. Google Reviews & Ratings (Opens in native Google Maps or Chrome where user is already logged in)
    final isGoogleReview = _reviewHosts.any((h) => host.contains(h)) ||
        (host.contains('google.') &&
            (uri.path.contains('review') ||
                uri.path.contains('maps') ||
                uri.path.contains('place') ||
                uri.queryParameters.containsKey('placeid') ||
                uri.queryParameters.containsKey('lrd') ||
                uri.fragment.contains('lrd')));

    if (isGoogleReview) {
      _launchExternalUrl(
        uri,
        'Google Review',
        mode: LaunchMode.externalApplication,
      );
      return NavigationDecision.prevent;
    }

    // 5. Google Maps & Direct Navigation
    if (_mapHosts.any((h) => host.contains(h))) {
      _launchExternalUrl(uri, 'Maps', mode: LaunchMode.externalApplication);
      return NavigationDecision.prevent;
    }

    // 6. Social media platforms (open in native apps if installed)
    if (_socialHosts.any((h) => host.contains(h))) {
      _launchExternalUrl(
        uri,
        'Social App',
        mode: LaunchMode.externalApplication,
      );
      return NavigationDecision.prevent;
    }

    // Default: allow navigation inside WebView (payment gateways, 3D Secure, OTPs)
    return NavigationDecision.navigate;
  }

  Future<void> _launchUpiPayment(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showUpiFallbackNotice();
      }
    } catch (e) {
      debugPrint('Could not launch UPI app: $e');
      _showUpiFallbackNotice();
    }
  }

  void _showUpiFallbackNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No UPI application (GPay, PhonePe, Paytm) found on device. Please select Card or NetBanking.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B4513),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _launchExternalUrl(
    Uri uri,
    String label, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: mode);
      }
    } catch (e) {
      debugPrint('Could not launch $label: $e');
    }
  }

  Future<void> retryLoading() async {
    if (isRetryingNotifier.value) return;
    isRetryingNotifier.value = true;

    try {
      final results = await Connectivity().checkConnectivity();
      final isConnected = results.any((r) => r != ConnectivityResult.none);

      if (!isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Still offline. Please enable Wi-Fi or Mobile Data.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF8B4513),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          );
        }
        return;
      }

      hasErrorNotifier.value = false;
      isLoadingNotifier.value = true;
      progressNotifier.value = 0;

      await controller.loadRequest(Uri.parse(websiteUrl));
    } finally {
      if (mounted) {
        isRetryingNotifier.value = false;
      }
    }
  }

  Future<void> handleBack() async {
    if (await controller.canGoBack()) {
      final currentUrl = await controller.currentUrl();
      // If user navigated back to root portal, break redirect loops and trigger double-tap to exit
      if (currentUrl != null &&
          (currentUrl == websiteUrl || currentUrl == '$websiteUrl/')) {
        _handleExitApp();
        return;
      }
      await controller.goBack();
    } else {
      _handleExitApp();
    }
  }

  void _handleExitApp() {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Press back again to exit',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF8B4513),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        );
      }
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _buildWebView() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }

  Widget _buildOfflineInterface() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Branded Logo with soft container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/mothers_hut_logo.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8B4513),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Please turn on Wi-Fi or Mobile Data to view dishes, place orders, and track your food deliveries.\nMother\'s Hut will auto-connect once you\'re back online.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 32),

              // Primary Action: Turn on Internet (opens Wireless settings)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openWirelessSettings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  label: const Text(
                    'Turn On Internet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Action: Retry Connection
              ValueListenableBuilder<bool>(
                valueListenable: isRetryingNotifier,
                builder: (context, isRetrying, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isRetrying ? null : retryLoading,
                      icon: isRetrying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF8B4513),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        isRetrying ? 'Checking connection...' : 'Try Again',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B4513),
                        side: const BorderSide(
                          color: Color(0xFF8B4513),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Auto-reconnect banner
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Auto-reconnect active when online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: hasErrorNotifier,
            builder: (context, hasError, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Primary WebView with Hybrid Composition - completely hidden when offline so Chromium's raw error never appears
                  Offstage(
                    offstage: hasError,
                    child: _buildWebView(),
                  ),

                  // 2. Full-Screen Skeleton Loader shown ONLY on Initial Cold Start
                  ValueListenableBuilder<bool>(
                    valueListenable: isInitialLoadNotifier,
                    builder: (context, isInitialLoad, _) {
                      if (!isInitialLoad || hasError) {
                        return const SizedBox.shrink();
                      }
                      return const SkeletonLoader();
                    },
                  ),

                  // 3. Smart, Branded Offline Interface
                  if (hasError)
                    Positioned.fill(
                      child: _buildOfflineInterface(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
