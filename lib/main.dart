import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isInitialLoadNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hasErrorNotifier = ValueNotifier<bool>(false);

  DateTime? _lastBackPressed;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Mother's Hut official web portal
  final String websiteUrl = 'https://mothershut.com';

  @override
  void initState() {
    super.initState();
    initializeWebView();
    _initConnectivityListener();
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
    super.dispose();
  }

  void initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            progressNotifier.value = value;
            if (value >= 100 && isLoadingNotifier.value) {
              isLoadingNotifier.value = false;
            }
          },

          onPageStarted: (url) {
            progressNotifier.value = 0;
            isLoadingNotifier.value = true;
            hasErrorNotifier.value = false;
          },

          onPageFinished: (url) {
            progressNotifier.value = 100;
            isLoadingNotifier.value = false;
            hasErrorNotifier.value = false;
            if (isInitialLoadNotifier.value) {
              isInitialLoadNotifier.value = false;
            }
          },

          onWebResourceError: (error) {
            // Only show the error screen when the main website frame fails.
            if (error.isForMainFrame == false) return;

            isLoadingNotifier.value = false;
            hasErrorNotifier.value = true;
          },

          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(websiteUrl));
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    // 1. Direct device schemes: Phone call, Email, SMS, Geolocation
    if (scheme == 'tel' ||
        scheme == 'mailto' ||
        scheme == 'sms' ||
        scheme == 'geo') {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (e) {
        debugPrint('Could not launch scheme $scheme: $e');
      }
      return NavigationDecision.prevent;
    }

    // 2. UPI & Payment applications
    if (scheme == 'upi' ||
        scheme == 'paytmmp' ||
        scheme == 'phonepe' ||
        scheme == 'tez' ||
        scheme == 'gpay') {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
      } catch (e) {
        debugPrint('Could not launch payment app: $e');
      }
      return NavigationDecision.prevent;
    }

    // 3. WhatsApp (Direct app or wa.me links)
    if (scheme == 'whatsapp' ||
        host.contains('wa.me') ||
        host.contains('whatsapp.com')) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
      } catch (e) {
        debugPrint('Could not launch WhatsApp: $e');
      }
      return NavigationDecision.prevent;
    }

    // 4. Google Maps & Navigation
    if (host.contains('maps.google.') ||
        host.contains('goo.gl') ||
        host.contains('maps.app.goo.gl')) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
      } catch (e) {
        debugPrint('Could not launch Maps: $e');
      }
      return NavigationDecision.prevent;
    }

    // 5. Social media platforms (open in native apps if installed)
    if (host.contains('instagram.com') ||
        host.contains('facebook.com') ||
        host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('twitter.com') ||
        host.contains('x.com')) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        }
      } catch (e) {
        debugPrint('Could not launch social app: $e');
      }
      return NavigationDecision.prevent;
    }

    // Default: allow navigation inside WebView (mothershut.com, payment gateways, etc.)
    return NavigationDecision.navigate;
  }

  Future<void> retryLoading() async {
    hasErrorNotifier.value = false;
    isLoadingNotifier.value = true;
    progressNotifier.value = 0;

    await controller.reload();
  }

  Future<void> handleBack() async {
    if (await controller.canGoBack()) {
      await controller.goBack();
    } else {
      // Double tap to exit
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
          child: Stack(
            children: [
              // Native WebView with direct touch handling (zero gesture-arena fighting)
              Positioned.fill(
                child: WebViewWidget(
                  controller: controller,
                ),
              ),

              // Full-Screen Skeleton Loader shown ONLY on Initial Cold Start
              ValueListenableBuilder<bool>(
                valueListenable: hasErrorNotifier,
                builder: (context, hasError, _) {
                  if (hasError) return const SizedBox.shrink();
                  return ValueListenableBuilder<bool>(
                    valueListenable: isInitialLoadNotifier,
                    builder: (context, isInitialLoad, _) {
                      return IgnorePointer(
                        ignoring: !isInitialLoad,
                        child: AnimatedOpacity(
                          opacity: isInitialLoad ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: isInitialLoad
                              ? ValueListenableBuilder<int>(
                                  valueListenable: progressNotifier,
                                  builder: (context, progress, _) {
                                    return SkeletonLoader(
                                      progress: progress,
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  );
                },
              ),

              // Sleek, Branded Top Progress Bar for In-Page Route Navigations
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: hasErrorNotifier,
                  builder: (context, hasError, _) {
                    if (hasError) return const SizedBox.shrink();
                    return ValueListenableBuilder<bool>(
                      valueListenable: isInitialLoadNotifier,
                      builder: (context, isInitialLoad, _) {
                        if (isInitialLoad) return const SizedBox.shrink();
                        return ValueListenableBuilder<bool>(
                          valueListenable: isLoadingNotifier,
                          builder: (context, isLoading, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable: progressNotifier,
                              builder: (context, progress, _) {
                                final isVisible =
                                    isLoading && progress > 0 && progress < 100;
                                return AnimatedOpacity(
                                  opacity: isVisible ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 180),
                                  child: isVisible
                                      ? LinearProgressIndicator(
                                          value: progress / 100.0,
                                          backgroundColor: Colors.transparent,
                                          valueColor:
                                              const AlwaysStoppedAnimation<Color>(
                                                Color(0xFF8B4513),
                                              ),
                                          minHeight: 2.5,
                                        )
                                      : const SizedBox(height: 2.5),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // Enhanced Branded Offline / Error Screen
              ValueListenableBuilder<bool>(
                valueListenable: hasErrorNotifier,
                builder: (context, hasError, _) {
                  if (!hasError) return const SizedBox.shrink();
                  return Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/mothers_hut_logo.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF8B4513,
                                      ).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.wifi_off_rounded,
                                      size: 48,
                                      color: Color(0xFF8B4513),
                                    ),
                                  ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Connection Problem',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Unable to connect to Mother\'s Hut.\n'
                            'Please check your internet connection. The app will auto-reconnect once back online.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 28),

                          ElevatedButton.icon(
                            onPressed: retryLoading,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B4513),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}
