import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectQuestionScreen extends StatefulWidget {
  final String examName;
  final String subjectName;

  SubjectQuestionScreen({
    required this.examName,
    required this.subjectName,
  });

  @override
  _SubjectQuestionScreenState createState() => _SubjectQuestionScreenState();
}

class _SubjectQuestionScreenState extends State<SubjectQuestionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, GlobalKey<_QuestionCardState>> _questionKeys = {};

  bool isLoading = true;
  List<QueryDocumentSnapshot> questions = [];
  List<String> years = [];
  String? selectedYear;
  String errorMessage = '';

  // 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadYearsAndQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 스크롤 컨트롤러 해제
    super.dispose();
  }

  // 연도 목록과 문제 데이터 로드
  Future<void> _loadYearsAndQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      // 1. 시험 문서에서 years 배열 가져오기
      DocumentSnapshot examDoc =
          await _firestore.collection('exams').doc(widget.examName).get();

      if (examDoc.exists && examDoc.data() != null) {
        Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;
        List<dynamic> yearList = data['years'] ?? [];

        if (yearList.isNotEmpty) {
          // 연도 목록 정렬 (내림차순 - 최신 연도가 먼저 오도록)
          List<String> sortedYears =
              yearList.map((year) => year.toString()).toList();
          sortedYears.sort((a, b) => b.compareTo(a)); // 내림차순 정렬

          // 가장 최신 연도를 기본값으로 설정
          String latestYear = sortedYears.first;

          setState(() {
            years = sortedYears;
            selectedYear = latestYear;
          });

          // 선택된 연도로 문제 로드
          await _loadQuestions(latestYear);
        } else {
          setState(() {
            errorMessage = '연도 정보를 찾을 수 없습니다';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = '시험 정보를 찾을 수 없습니다';
          isLoading = false;
        });
      }
    } catch (e) {
      print('연도 및 문제 로딩 오류: $e');
      setState(() {
        errorMessage = '데이터를 로드하는 데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 특정 연도의 문제만 로드
  Future<void> _loadQuestions(String year) async {
    setState(() {
      isLoading = true;
      questions = []; // 문제 목록 초기화
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      print(
          '로드 시도: exam=${widget.examName}, subject=${widget.subjectName}, year=$year');

      // questions 컬렉션에서 Category와 Year 필드로 필터링
      final QuerySnapshot snapshot = await _firestore
          .collection('exams')
          .doc(widget.examName)
          .collection('questions')
          .where('Category', isEqualTo: widget.subjectName)
          .where('Year', isEqualTo: year)
          .orderBy('Question_id') // Question_id 순으로 정렬
          .get();

      print('쿼리 결과: ${snapshot.docs.length}개의 문제 로드됨');

      setState(() {
        questions = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      print('문제 로딩 오류: $e');
      setState(() {
        errorMessage = '문제를 불러오는 중 오류가 발생했습니다: $e';
        isLoading = false;
      });

      // 오류 발생 시 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('문제를 불러오는 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red.shade300,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 모든 문제 초기화
  void _resetAllQuestions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('초기화 확인'),
        content: Text('모든 문제의 선택을 초기화하시겠습니까?'),
        actions: [
          TextButton(
            child: Text('취소'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: Text('초기화'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              _questionKeys.forEach((_, key) {
                if (key.currentState != null) {
                  // 각 QuestionCard의 상태 초기화 메서드 호출
                  key.currentState!.resetQuestion();
                }
              });
              Navigator.pop(context); // 다이얼로그 닫기

              // 초기화 완료 메시지 표시
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('모든 문제가 초기화되었습니다'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.black,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ], // actions 닫는 괄호
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ), // AlertDialog 닫는 괄호
    ); // showDialog 닫는 괄호
  }

  // 학습 정보 다이얼로그 표시
  void _showInfoDialog(BuildContext context, String examName, String subjectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('학습 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: '시험: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: examName),
                ],
              ),
            ),
            SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: '과목: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: subjectName),
                ],
              ),
            ),
            if (selectedYear != null) ...[
              SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '연도: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: selectedYear!),
                  ],
                ),
              ),
            ],
            SizedBox(height: 16),
            Text(
              '학습 팁:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('- 각 문제를 천천히 읽고 이해하세요'),
            Text('- 오답을 체크하고 다시 풀어보세요'),
            Text('- 실제 시험처럼 시간을 정해 풀어보세요'),
            Text('- 연도별로 문제 유형을 비교해보세요'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('확인'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: false,
        toolbarHeight: 40, // 앱바 높이 축소
        title: Text(
          widget.subjectName, // 과목 이름 표시
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            onPressed: _resetAllQuestions,
            tooltip: '모든 문제 초기화',
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            onPressed: () {
              _showInfoDialog(context, widget.examName, widget.subjectName);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 연도 선택 영역
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8), // 패딩 조절
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 연도 선택 드롭다운
                if (years.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 14, // 아이콘 크기 조절
                      ),
                      SizedBox(width: 6), // 간격 조절
                      Text(
                        '연도 선택:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14, // 폰트 크기 조절
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4), // 간격 조절
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0), // 내부 패딩 조절
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedYear,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: Colors.black, size: 20), // 아이콘 크기 조절
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14, // 폰트 크기 조절
                          fontWeight: FontWeight.w500,
                        ),
                        items: years.map((String year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != selectedYear) {
                            setState(() {
                              selectedYear = newValue;
                            });
                            _loadQuestions(newValue); // 새 연도 선택 시 문제 로드
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 문제 컨텐츠 영역
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '문제를 불러오는 중입니다...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : questions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              selectedYear != null
                                  ? '$selectedYear 연도에 해당 과목의 문제가 없습니다'
                                  : '해당 과목의 문제가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (errorMessage.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[400],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (selectedYear != null) {
                                  _loadQuestions(selectedYear!);
                                } else {
                                  // 연도 정보가 없을 때 초기 로드 함수 재호출
                                  _loadYearsAndQuestions();
                                }
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('다시 시도'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), // 패딩 적용
                        child: _buildGridView(), // 그리드 뷰 표시
                      ),
          ),
        ],
      ),
    );
  }

  // 2단 그리드 뷰 생성 (ListView & Row 사용)
  Widget _buildGridView() {
    int questionCount = questions.length;

    return Column(
      children: [
        // 간략한 요약 정보
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          margin: EdgeInsets.only(bottom: 4),
          child: Text(
            '총 ${questionCount}문항', // 동적으로 문제 개수 표시
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),

        // ListView 사용하여 Row로 2개씩 배치
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: (questionCount / 2).ceil(), // 2개씩 묶어서 표시할 행 수 계산
            cacheExtent: 500, // 스크롤 성능 개선을 위한 캐시 범위 설정
            itemBuilder: (context, rowIndex) {
              final leftIndex = rowIndex * 2;
              final rightIndex = rowIndex * 2 + 1;

              return Padding(
                padding: EdgeInsets.only(bottom: 6.0), // 행 간격
                child: IntrinsicHeight( // Row 내부 위젯들의 높이를 가장 큰 위젯에 맞춤
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // 카드 상단 정렬
                    children: [
                      // 왼쪽 카드
                      Expanded(
                        child: leftIndex < questionCount
                            ? _buildSafeQuestionCard(leftIndex)
                            : SizedBox(), // 왼쪽 아이템이 없으면 빈 공간
                      ),
                      SizedBox(width: 6.0), // 열 간격
                      // 오른쪽 카드
                      Expanded(
                        child: rightIndex < questionCount
                            ? _buildSafeQuestionCard(rightIndex)
                            : SizedBox(), // 오른쪽 아이템이 없으면 빈 공간
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 안전하게 QuestionCard 위젯 생성 (오류 처리 포함)
  Widget _buildSafeQuestionCard(int index) {
    try {
      final doc = questions[index]; // 해당 인덱스의 문서 가져오기
      if (doc == null) {
        print('Error: Document is null at index $index');
        return SizedBox(); // 문서 없으면 빈 위젯
      }

      final docId = doc.id;
      if (docId == null || docId.isEmpty) {
        print('Error: Document ID is null or empty at index $index');
        return SizedBox(); // ID 없으면 빈 위젯
      }

      // GlobalKey 관리
      if (!_questionKeys.containsKey(docId)) {
        _questionKeys[docId] = GlobalKey<_QuestionCardState>();
      }

      // QuestionCard 위젯 반환
      return QuestionCard(
        key: _questionKeys[docId],
        doc: doc,
        isCompact: true, // 컴팩트 모드 활성화
      );
    } catch (e, stackTrace) {
      print('Error building QuestionCard at index $index: $e');
      print(stackTrace);
      return SizedBox(); // 오류 발생 시 빈 위젯 반환
    }
  }
}


//-------------------------------------------------------------------
// 개별 문제 카드 위젯 (QuestionCard)
//-------------------------------------------------------------------
class QuestionCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final bool isCompact; // 컴팩트 모드 여부

  QuestionCard({
    Key? key,
    required this.doc,
    this.isCompact = false,
  }) : super(key: key);

  @override
  _QuestionCardState createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  int? userChoice;
  bool showExplanation = false;

  // 문제 초기화 메서드
  void resetQuestion() {
    if (mounted) { // 위젯이 마운트된 상태인지 확인
      setState(() {
        userChoice = null;
        showExplanation = false;
      });
    }
  }

  // Base64 이미지인지 확인
  bool isBase64Image(String? data) {
    return data != null && data.startsWith('data:image');
  }

  // Base64 데이터를 이미지 위젯으로 변환
  Widget buildImage(String base64String, {bool isOption = false}) {
    try {
      final bytes = base64Decode(base64String.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8), // 이미지 모서리 둥글게
        child: Image.memory(
          bytes,
          fit: BoxFit.contain, // 이미지 비율 유지하며 채우기
          width: isOption ? 120 : double.infinity, // 옵션 이미지 크기 조절
          height: isOption ? 80 : 160, // 높이 조절
          errorBuilder: (context, error, stackTrace) { // 이미지 로딩 오류 시 처리
            return Center(child: Text('이미지 로딩 실패', style: TextStyle(fontSize: 10)));
          },
        ),
      );
    } catch (e) {
      print('Base64 이미지 디코딩 오류: $e');
      return Center(
        child: Text(
          '이미지 오류',
          style: TextStyle(color: Colors.red.shade400, fontSize: 12),
        ),
      );
    }
  }

  // 문제 텍스트 또는 이미지 위젯 생성
  Widget buildQuestion(String? question) {
    if (question == null || question.trim().isEmpty) {
      return SizedBox.shrink(); // 내용 없으면 빈 위젯
    } else if (isBase64Image(question)) {
      return buildImage(question, isOption: false); // 이미지 표시
    } else {
      // 텍스트 문제 표시
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(widget.isCompact ? 10 : 16), // 컴팩트 모드 패딩 조절
        decoration: BoxDecoration(
          color: Colors.grey.shade50, // 배경색
          borderRadius: BorderRadius.circular(8), // 모서리 둥글게
          border: Border.all(color: Colors.grey.shade200), // 테두리
        ),
        child: Text(
          question,
          style: TextStyle(
            fontSize: widget.isCompact ? 13 : 16, // 컴팩트 모드 폰트 크기 조절
            height: 1.4, // 줄 간격
            color: Colors.black87,
          ),
        ),
      );
    }
  }

  // 선택지 텍스트 또는 이미지 위젯 생성
  Widget buildOption(String? option, bool isSelected, bool isCorrect, bool hasSelected) {
    if (option == null) {
      return Text(
        '옵션 없음',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
          fontSize: widget.isCompact ? 11 : 13, // 컴팩트 모드 폰트 크기 조절
        ),
      );
    } else if (isBase64Image(option)) {
      return buildImage(option, isOption: true); // 이미지 옵션
    } else {
      // 텍스트 옵션
      String displayText = option;
      Color textColor = Colors.black87; // 기본 텍스트 색상

      // 선택 후 상태에 따른 스타일 변경 (컴팩트 모드에서는 아이콘으로 대체)
      if (hasSelected && !widget.isCompact) {
         if (isSelected) {
           textColor = isCorrect ? Colors.green.shade700 : Colors.red.shade700;
         } else if (isCorrect) {
           textColor = Colors.green.shade700; // 정답 옵션 강조
         }
      }

      return Text(
        displayText,
        style: TextStyle(
          fontSize: widget.isCompact ? 12 : 14, // 컴팩트 모드 폰트 크기 조절
          color: textColor,
        ),
        maxLines: widget.isCompact ? 3 : null, // 컴팩트 모드 줄 수 제한
        overflow: widget.isCompact ? TextOverflow.ellipsis : TextOverflow.visible, // 넘칠 경우 ... 처리
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 데이터 추출 및 null 처리 강화
    final data = widget.doc.data() as Map<String, dynamic>? ?? {};
    final int correctOption = data['Correct_Option'] as int? ?? 0;
    // final String category = data['Category'] as String? ?? ''; // 현재 사용 안 함

    // 옵션 개수 동적 확인
    int optionCount = 4; // 기본 4개
    for (int i = 5; i <= 10; i++) { // 최대 10개 옵션까지 확인 (필요시 조절)
      if (data.containsKey('Option$i') && data['Option$i'] != null && data['Option$i'].toString().isNotEmpty) {
        optionCount = i;
      } else {
        break; // 연속되지 않으면 중단
      }
    }


    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200), // 카드 테두리
        color: Colors.white,
        boxShadow: [ // 약간의 그림자 효과
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Column 높이를 내용에 맞춤
        children: [
          // 문제 헤더 (문제 번호, 초기화 버튼)
          Container(
            padding: EdgeInsets.all(widget.isCompact ? 8 : 12), // 컴팩트 모드 패딩 조절
            decoration: BoxDecoration(
              color: Colors.grey.shade50, // 헤더 배경색
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // 문제 번호 표시
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isCompact ? 8 : 10,
                    vertical: widget.isCompact ? 3 : 5
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black, // 배경색
                    borderRadius: BorderRadius.circular(12), // 둥근 모서리
                  ),
                  child: Text(
                    '${data['Question_id'] ?? '?'}', // null 처리
                    style: TextStyle(
                      fontSize: widget.isCompact ? 11 : 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Spacer(), // 오른쪽으로 밀기
                // 초기화 버튼 (선택했을 때만 표시)
                if (userChoice != null)
                  TextButton.icon(
                    onPressed: resetQuestion,
                    icon: Icon(Icons.refresh, size: widget.isCompact ? 12 : 16),
                    label: Text(
                      '초기화',
                      style: TextStyle(fontSize: widget.isCompact ? 10 : 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isCompact ? 4 : 6,
                        vertical: widget.isCompact ? 0 : 2
                      ),
                      minimumSize: Size(0, 0), // 버튼 최소 크기 제거
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 탭 영역 축소
                    ),
                  ),
              ],
            ),
          ),

          // 문제 내용 섹션 (스크롤 가능)
          // Flexible을 사용하여 남은 공간을 차지하도록 함
          Padding( // 내부 패딩을 Column 밖으로 이동
            padding: EdgeInsets.all(widget.isCompact ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Column 높이를 내용에 맞춤
              children: [
                // Big Question (메인 질문)
                if (data.containsKey('Big_Question') && data['Big_Question'] != null && data['Big_Question'].toString().isNotEmpty)
                  Padding( // Big Question 위아래 간격 조정
                    padding: EdgeInsets.only(bottom: widget.isCompact ? 8 : 12),
                    child: Text(
                      data['Big_Question'],
                      style: TextStyle(
                        fontSize: widget.isCompact ? 14 : 17, // 폰트 크기 조절
                        fontWeight: FontWeight.w600, // 약간 굵게
                        color: Colors.black,
                      ),
                    ),
                  ),

                // 부가 질문 (Question 필드)
                if (data.containsKey('Question') && data['Question'] != null && data['Question'].toString().trim().isNotEmpty)
                  Padding( // 부가 질문 아래 간격
                    padding: EdgeInsets.only(bottom: widget.isCompact ? 8 : 12),
                    child: buildQuestion(data['Question']),
                  ),

                SizedBox(height: widget.isCompact ? 6 : 10), // 질문과 선택지 사이 간격

                // 선택지 목록
                Column(
                  mainAxisSize: MainAxisSize.min, // Column 높이를 내용에 맞춤
                  children: List.generate(optionCount, (optionIndex) {
                    int optionNumber = optionIndex + 1;
                    String? optionText = data['Option$optionNumber'];
                    bool isSelected = userChoice == optionNumber;
                    bool isCorrect = correctOption == optionNumber;

                    return InkWell(
                      onTap: () {
                        if (userChoice == null && mounted) { // 선택 전이고 마운트 상태일 때만
                          setState(() {
                            userChoice = optionNumber;
                            showExplanation = true;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8), // 탭 효과 범위
                      child: Container(
                        margin: EdgeInsets.only(bottom: widget.isCompact ? 5 : 8), // 선택지 간 간격
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isCompact ? 10 : 12,
                          vertical: widget.isCompact ? 8 : 10
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all( // 선택 상태에 따른 테두리 스타일
                            color: userChoice != null
                                ? isSelected
                                    ? isCorrect
                                        ? Colors.green.shade300
                                        : Colors.red.shade300
                                    : isCorrect
                                        ? Colors.green.shade300 // 정답 강조
                                        : Colors.grey.shade200
                                : Colors.grey.shade200, // 기본 테두리
                            width: 1.5, // 테두리 두께
                          ),
                          color: userChoice != null // 선택 상태에 따른 배경색
                              ? isSelected
                                  ? isCorrect
                                      ? Colors.green.shade50
                                      : Colors.red.shade50
                                  : isCorrect
                                      ? Colors.green.shade50 // 정답 배경 강조
                                      : Colors.white
                              : Colors.white, // 기본 배경색
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // 아이콘과 텍스트 상단 정렬
                          children: [
                            // 선택지 번호 동그라미
                            Container(
                              width: widget.isCompact ? 20 : 24,
                              height: widget.isCompact ? 20 : 24,
                              margin: EdgeInsets.only(
                                right: widget.isCompact ? 8 : 10,
                                top: 1 // 텍스트와 높이 미세 조정
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: userChoice != null // 선택 상태에 따른 동그라미 색상
                                    ? isSelected
                                        ? isCorrect
                                            ? Colors.green // 정답 녹색
                                            : Colors.red // 오답 빨강
                                        : isCorrect
                                            ? Colors.green // 정답 강조
                                            : Colors.grey.shade300 // 비선택 회색
                                    : Colors.grey.shade300, // 기본 회색
                              ),
                              child: Text(
                                '$optionNumber',
                                style: TextStyle(
                                  fontSize: widget.isCompact ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: userChoice != null // 선택 상태에 따른 숫자 색상
                                      ? (isSelected || isCorrect) // 선택했거나 정답이면 흰색
                                          ? Colors.white
                                          : Colors.black54 // 그 외 어두운 회색
                                      : Colors.black54, // 기본 어두운 회색
                                ),
                              ),
                            ),
                            // 선택지 내용 (텍스트 또는 이미지)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildOption(
                                    optionText,
                                    isSelected,
                                    isCorrect,
                                    userChoice != null,
                                  ),
                                  // 컴팩트 모드: 정답/오답 아이콘 표시
                                  if (userChoice != null && widget.isCompact) ...[
                                    SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (isSelected && isCorrect)
                                          Icon(Icons.check_circle, color: Colors.green, size: 12)
                                        else if (isSelected && !isCorrect)
                                          Icon(Icons.cancel, color: Colors.red, size: 12)
                                        else if (!isSelected && isCorrect)
                                          Icon(Icons.radio_button_unchecked, color: Colors.green, size: 12), // 정답 아이콘
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                // 해설 표시
                if (showExplanation && userChoice != null && data.containsKey('Answer_description') && data['Answer_description'] != null && data['Answer_description'].toString().isNotEmpty) ...[
                  SizedBox(height: widget.isCompact ? 8 : 12), // 선택지와 해설 사이 간격
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(widget.isCompact ? 10 : 14), // 해설 패딩
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50, // 해설 배경색 변경
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueGrey.shade100), // 해설 테두리
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blueGrey.shade700, // 아이콘 색상 변경
                              size: widget.isCompact ? 14 : 18,
                            ),
                            SizedBox(width: widget.isCompact ? 5 : 8),
                            Text(
                              '해설',
                              style: TextStyle(
                                fontSize: widget.isCompact ? 12 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade800, // 텍스트 색상 변경
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isCompact ? 5 : 8), // 제목과 내용 사이 간격
                        Text(
                          data['Answer_description'] ?? '', // null 처리
                          style: TextStyle(
                            fontSize: widget.isCompact ? 11 : 13, // 해설 폰트 크기
                            height: 1.4, // 줄 간격
                            color: Colors.black.withOpacity(0.75), // 약간 연하게
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ], // Padding 내부 Column의 children 닫기
            ), // Padding 닫기
          ), // 문제 내용 섹션 Column 닫기
        ], // 메인 Column의 children 닫기
      ), // Container 닫기
    ); // build 메서드 닫기
  }
} // _QuestionCardState 클래스 닫기