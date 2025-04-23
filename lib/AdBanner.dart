import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web; // Flutter 3.19 이상에서 사용
import 'dart:js_util' as js_util; // js_util 임포트

class AdBanner extends StatefulWidget {
  final double height;
  final String adUnitId;
  final String publisherId;

  AdBanner({
    this.height = 100.0,
    required this.adUnitId,
    required this.publisherId,
  });

  @override
  _AdBannerState createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  late String _adUniqueId;

  @override
  void initState() {
    super.initState();
    _adUniqueId = 'ad-container-${DateTime.now().microsecondsSinceEpoch}';
    _createAdsElement();
  }

  void _createAdsElement() {
    final existingElement = html.document.getElementById(_adUniqueId);
    if (existingElement != null) {
      existingElement.remove();
    }

    final adDiv = html.DivElement()
      ..id = _adUniqueId
      ..style.width = '100%'
      ..style.height = '${widget.height}px'
      ..style.border = 'none'
      ..style.display = 'flex'
      ..style.justifyContent = 'center'
      ..style.alignItems = 'center';

    final insElement = html.Element.tag('ins')
      ..className = 'adsbygoogle'
      ..style.display = 'block'
      ..style.width = '100%'
      ..style.height = '${widget.height}px'
      ..attributes['data-ad-client'] = 'ca-pub-${widget.publisherId}'
      ..attributes['data-ad-slot'] = widget.adUnitId
      ..attributes['data-ad-format'] = 'auto'
      ..attributes['data-full-width-responsive'] = 'true';

    adDiv.append(insElement);

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _adUniqueId,
      (int viewId) => adDiv,
    );

    // AdSense 스크립트 push 실행 (js_util 사용)
    Future.microtask(() {
      try {
        // window 객체에서 adsbygoogle 가져오기
        var adsbygoogle = js_util.getProperty(html.window, 'adsbygoogle');

        // adsbygoogle가 null 또는 undefined가 아니면 push 메소드 호출
        if (adsbygoogle != null) {
          // 빈 JavaScript 객체 {} 생성
          var emptyJsObject = js_util.newObject();
          // adsbygoogle 객체의 push 메소드를 호출하고 빈 객체를 인수로 전달
          js_util.callMethod(adsbygoogle, 'push', [emptyJsObject]);
          print('AdSense push executed for $_adUniqueId using js_util');
        } else {
          // adsbygoogle가 아직 준비되지 않았을 수 있으므로, 배열로 초기화하고 push 시도
          adsbygoogle = js_util.setProperty(html.window, 'adsbygoogle', []);
           var emptyJsObject = js_util.newObject();
          js_util.callMethod(adsbygoogle, 'push', [emptyJsObject]);
           print('AdSense push executed for $_adUniqueId after initialization using js_util');
        }
      } catch (e) {
        print('Error pushing adsbygoogle using js_util: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: HtmlElementView(
        viewType: _adUniqueId,
      ),
    );
  }

  @override
  void dispose() {
    final element = html.document.getElementById(_adUniqueId);
    if (element != null) {
      element.remove();
      print('Ad element removed: $_adUniqueId');
    }
    super.dispose();
  }
}