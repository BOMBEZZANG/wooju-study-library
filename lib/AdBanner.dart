import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class AdBanner extends StatefulWidget {
  final double height;
  final String adUnitId;

  AdBanner({
    this.height = 100.0,
    required this.adUnitId,
  });

  @override
  _AdBannerState createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  // iframe의 uniqueId
  late String _adUniqueId;

  @override
  void initState() {
    super.initState();
    // 고유 ID 생성
    _adUniqueId = 'ad-container-${DateTime.now().microsecondsSinceEpoch}';
    // 광고 요소 생성
    _createAdsElement();
  }

  void _createAdsElement() {
    // HTML Div 요소 생성
    final adDiv = html.DivElement()
      ..id = _adUniqueId
      ..style.width = '100%'
      ..style.height = '${widget.height}px';

    // 필요한 스크립트들을 추가
    final script = html.ScriptElement()
      ..text = '''
        // AdSense 광고 코드 (실제 사용 시 교체해야 함)
        (function() {
          window.addEventListener('load', function() {
            if (typeof(window.adsbygoogle) !== 'undefined') {
              var ins = document.createElement('ins');
              ins.className = 'adsbygoogle';
              ins.style.display = 'block';
              ins.setAttribute('data-ad-client', 'ca-pub-YOUR-CLIENT-ID');
              ins.setAttribute('data-ad-slot', '${widget.adUnitId}');
              ins.setAttribute('data-ad-format', 'auto');
              ins.setAttribute('data-full-width-responsive', 'true');
              
              var adContainer = document.getElementById('${_adUniqueId}');
              adContainer.appendChild(ins);
              
              (adsbygoogle = window.adsbygoogle || []).push({});
            }
          });
        })();
      ''';

    // div에 스크립트 추가
    adDiv.append(script);

    // body에 요소 추가
    html.document.body?.append(adDiv);

    // UI 요소 등록 (수정된 부분)
    ui_web.platformViewRegistry.registerViewFactory(
      _adUniqueId,
      (int viewId) {
        return adDiv;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: HtmlElementView(
        viewType: _adUniqueId,
      ),
    );
  }

  @override
  void dispose() {
    // 페이지를 떠날 때 요소 제거
    final element = html.document.getElementById(_adUniqueId);
    if (element != null) {
      element.remove();
    }
    super.dispose();
  }
}