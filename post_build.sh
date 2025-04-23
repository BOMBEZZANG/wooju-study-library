#!/bin/bash
# Firebase SDK 스크립트를 빌드된 index.html에 삽입

BUILD_DIR="build/web"
INDEX_FILE="${BUILD_DIR}/index.html"

# 임시 파일
TEMP_FILE="${BUILD_DIR}/index.tmp"

# index.html 파일이 존재하는지 확인
if [ ! -f "$INDEX_FILE" ]; then
  echo "오류: ${INDEX_FILE}을 찾을 수 없습니다."
  exit 1
fi

# 간단한 sed 명령어로 </head> 태그 앞에 스크립트 추가
# Mac OS와 Linux 간 sed 명령어 차이를 고려
if [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OS용 sed 명령
  sed -i '' '/<\/head>/i\
  <!-- Google Analytics -->\
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-GM4G7KF2S6"></script>\
  <script>\
    window.dataLayer = window.dataLayer || [];\
    function gtag(){dataLayer.push(arguments);}\
    gtag("js", new Date());\
    gtag("config", "G-GM4G7KF2S6");\
  </script>\
  <script src="firebase-config.js"></script>\
  ' "$INDEX_FILE"
else
  # Linux용 sed 명령
  sed -i '/<\/head>/i\
  <!-- Google Analytics -->\
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-GM4G7KF2S6"></script>\
  <script>\
    window.dataLayer = window.dataLayer || [];\
    function gtag(){dataLayer.push(arguments);}\
    gtag("js", new Date());\
    gtag("config", "G-GM4G7KF2S6");\
  </script>\
  <script src="firebase-config.js"></script>\
  ' "$INDEX_FILE"
fi

# 성공 메시지 출력
echo "Google Analytics 스크립트와 firebase-config.js가 ${INDEX_FILE}에 추가되었습니다."

exit 0