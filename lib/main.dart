import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';
import 'dart:html' as html;
import 'firebase_options.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 초기화 디버깅
  debugPrint('Firebase 초기화 완료');
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  // JS 콘솔에 로그 출력을 위한 메서드
  void _consoleLog(String message) {
    html.window.console.log(message);
  }

  @override
  Widget build(BuildContext context) {
    // 애널리틱스가 활성화되어 있는지 확인
    _setupAnalytics();
    
    return MaterialApp(
      title: '우주도서관 SPACE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      navigatorObservers: [observer], // Analytics 관찰자 등록
      home: HomePage(),
    );
  }
  
  // 애널리틱스 설정 및 초기 이벤트 발송
  Future<void> _setupAnalytics() async {
    try {
      // 애널리틱스 수집 활성화
      await analytics.setAnalyticsCollectionEnabled(true);
      _consoleLog('[Flutter] Analytics 수집이 활성화되었습니다.');
      
      // 사용자 속성 설정
      await analytics.setUserProperty(name: 'platform', value: 'web');
      
      // 앱 오픈 이벤트 로깅
      await analytics.logAppOpen();
      _consoleLog('[Flutter] App Open 이벤트가 전송되었습니다.');
      
      // 커스텀 이벤트 로깅
      await analytics.logEvent(
        name: 'flutter_init_complete',
        parameters: {
          'timestamp': DateTime.now().toString(),
        },
      );
      _consoleLog('[Flutter] 초기화 완료 이벤트가 전송되었습니다.');
      
      // 현재 화면 설정
      await analytics.setCurrentScreen(screenName: 'home_screen');
      _consoleLog('[Flutter] 현재 화면이 설정되었습니다: home_screen');
    } catch (e) {
      _consoleLog('[Flutter] Analytics 초기화 오류: $e');
      debugPrint('Analytics 오류: $e');
    }
  }
}