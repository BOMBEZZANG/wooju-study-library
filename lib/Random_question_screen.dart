import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RandomQuestionScreen extends StatefulWidget {
  final String examName;

  RandomQuestionScreen({
    required this.examName,
  });

  @override
  _RandomQuestionScreenState createState() => _RandomQuestionScreenState();
}

class _RandomQuestionScreenState extends State<RandomQuestionScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, GlobalKey<_QuestionCardState>> _questionKeys = {};

  bool isLoading = true;
  List<QueryDocumentSnapshot> questions = [];
  List<String> categories = [];
  String? selectedCategory;
  String errorMessage = '';
  final int maxQuestions = 100; // 최대 표시할 문제 수

  // 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // 스크롤 컨트롤러 해제
    super.dispose();
  }

  // 카테고리 목록과 랜덤 문제 데이터 로드
  Future<void> _loadCategoriesAndQuestions() async {
    if (!mounted) return; // 위젯이 unmount된 후 setState 호출 방지
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      // 1. 시험 문서에서 categories 배열 가져오기
      DocumentSnapshot examDoc =
          await _firestore.collection('exams').doc(widget.examName).get();

      if (examDoc.exists && examDoc.data() != null) {
        Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;
        List<dynamic> categoryList = data['categories'] ?? [];

        // 카테고리 목록에 '전체' 옵션 추가
        List<String> allCategories = ['전체'];
        allCategories.addAll(categoryList.map((category) => category.toString()));

        if (!mounted) return;
        setState(() {
          categories = allCategories;
          selectedCategory = '전체'; // 기본값으로 '전체' 설정
        });

        // 기본값(전체 카테고리)으로 문제 로드
        await _loadRandomQuestions(selectedCategory);
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = '시험 정보를 찾을 수 없습니다';
          isLoading = false;
        });
      }
    } catch (e) {
      print('카테고리 및 문제 로딩 오류: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = '데이터를 로드하는 데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 선택된 카테고리의 랜덤 문제 로드
  Future<void> _loadRandomQuestions(String? category) async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      questions = []; // 문제 목록 초기화
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      print('랜덤 문제 로드 시도: exam=${widget.examName}, category=$category');

      // 쿼리 구성: 카테고리가 '전체'이면 모든 문제, 아니면 특정 카테고리 문제만
      Query query = _firestore
          .collection('exams')
          .doc(widget.examName)
          .collection('questions');

      if (category != null && category != '전체') {
        query = query.where('Category', isEqualTo: category);
      }

      // 쿼리 실행
      final QuerySnapshot snapshot = await query.get();

      print('쿼리 결과: ${snapshot.docs.length}개의 문제 로드됨');

      // 결과가 있으면 랜덤으로 섞어서 최대 maxQuestions개 선택
      if (snapshot.docs.isNotEmpty) {
        List<QueryDocumentSnapshot> allQuestions = List.from(snapshot.docs);
        allQuestions.shuffle(Random()); // 랜덤 섞기

        // 최대 maxQuestions개까지만 선택
        List<QueryDocumentSnapshot> randomQuestions =
            allQuestions.length > maxQuestions
                ? allQuestions.sublist(0, maxQuestions)
                : allQuestions;

        // Question_id 순으로 정렬 (선택 사항)
        randomQuestions.sort((a, b) {
          // 안전하게 데이터 접근 및 형변환
          var aData = a.data() as Map<String, dynamic>? ?? {};
          var bData = b.data() as Map<String, dynamic>? ?? {};
          var aId = aData['Question_id'] as int? ?? 0;
          var bId = bData['Question_id'] as int? ?? 0;
          return aId.compareTo(bId);
        });

        if (!mounted) return;
        setState(() {
          questions = randomQuestions;
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          questions = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('랜덤 문제 로딩 오류: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = '문제를 불러오는 중 오류가 발생했습니다: $e';
        isLoading = false;
      });

      // 사용자에게 오류 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('문제를 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red.shade300,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 새로운 랜덤 문제 세트 로드
  void _loadNewRandomSet() {
    _loadRandomQuestions(selectedCategory); // 현재 선택된 카테고리로 다시 로드

    // 사용자에게 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('새로운 랜덤 문제를 불러왔습니다'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black,
        duration: Duration(seconds: 2),
      ),
    );
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
  void _showInfoDialog(BuildContext context, String examName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('랜덤 문제 학습 정보'),
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
                  TextSpan(text: selectedCategory ?? '전체'),
                ],
              ),
            ),
            SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: '문제 수: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '${questions.length}문제'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '학습 팁:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('- 랜덤 문제로 다양한 유형에 대비하세요'),
            Text('- 과목 필터를 사용하여 약점 분야를 집중적으로 공부하세요'),
            Text('- 새로운 랜덤 세트를 통해 더 많은 문제를 풀어보세요'),
            Text('- 최대 ${maxQuestions}문제까지 한 번에 학습할 수 있습니다'),
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
          '랜덤 기출문제',
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
              _showInfoDialog(context, widget.examName);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 정보 및 컨트롤 영역
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8), // 패딩 조절
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시험 이름
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0), // 시험 이름 아래 간격
                  child: Text(
                    widget.examName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16, // 폰트 크기 조절
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // 카테고리 선택
                Row(
                  children: [
                    Text(
                      '과목 선택:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14, // 폰트 크기 조절
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36, // 드롭다운 높이 고정
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0), // 내부 패딩 조절
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1), // 배경 투명도
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            dropdownColor: Colors.grey.shade900, // 드롭다운 배경색
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20), // 아이콘 크기
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14, // 폰트 크기
                            ),
                            items: categories.map((String category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category, overflow: TextOverflow.ellipsis), // 넘칠 경우 ...
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null && newValue != selectedCategory) {
                                setState(() {
                                  selectedCategory = newValue;
                                });
                                _loadRandomQuestions(newValue); // 새 카테고리 선택 시 문제 로드
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8), // 드롭다운과 버튼 사이 간격

                // 새로운 랜덤 문제 세트 버튼
                SizedBox(
                  width: double.infinity,
                  height: 36, // 버튼 높이 조절
                  child: ElevatedButton.icon(
                    onPressed: _loadNewRandomSet,
                    icon: Icon(Icons.shuffle, size: 16), // 아이콘 크기 조절
                    label: Text('새로운 랜덤 문제', style: TextStyle(fontSize: 14)), // 버튼 텍스트 크기
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // 버튼 배경색
                      foregroundColor: Colors.black, // 버튼 글자/아이콘 색상
                      elevation: 0, // 그림자 제거
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // 버튼 모서리 둥글게
                      ),
                      padding: EdgeInsets.symmetric(vertical: 0), // 버튼 내부 수직 패딩 제거
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 문제 컨텐츠 영역
          Expanded(
            child: isLoading
                ? Center( // 로딩 중 표시
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
                    ? Center( // 문제 없을 때 표시
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
                              selectedCategory == '전체'
                                  ? '랜덤 문제가 없습니다'
                                  : '$selectedCategory 과목의 문제가 없습니다',
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
                                padding: const EdgeInsets.symmetric(horizontal: 32),
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
                            ElevatedButton.icon( // 다시 시도 버튼
                              onPressed: () {
                                _loadRandomQuestions(selectedCategory);
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('다시 시도'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding( // 문제 목록 표시
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), // 그리드 뷰 패딩
                        child: _buildGridView(), // 그리드 뷰 생성
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
            '랜덤 문제 ${questionCount}개 (${selectedCategory == '전체' ? '전체 과목' : selectedCategory})',
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
            itemCount: (questionCount / 2).ceil(), // 행 수 계산
            cacheExtent: 500, // 스크롤 성능 개선
            itemBuilder: (context, rowIndex) {
              final leftIndex = rowIndex * 2;
              final rightIndex = rowIndex * 2 + 1;

              return Padding(
                padding: EdgeInsets.only(bottom: 6.0), // 행 간격
                child: IntrinsicHeight( // Row 내부 위젯 높이 맞춤
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start, // 카드 상단 정렬
                    children: [
                      // 왼쪽 카드
                      Expanded(
                        child: leftIndex < questionCount
                            ? _buildSafeQuestionCard(leftIndex)
                            : SizedBox(), // 아이템 없으면 빈 공간
                      ),
                      SizedBox(width: 6.0), // 열 간격
                      // 오른쪽 카드
                      Expanded(
                        child: rightIndex < questionCount
                            ? _buildSafeQuestionCard(rightIndex)
                            : SizedBox(), // 아이템 없으면 빈 공간
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
      final doc = questions[index]; // 해당 인덱스 문서
      if (doc == null) {
        print('Error: Document is null at index $index');
        return SizedBox();
      }

      final docId = doc.id;
      if (docId == null || docId.isEmpty) {
        print('Error: Document ID is null or empty at index $index');
        return SizedBox();
      }

      // GlobalKey 관리
      if (!_questionKeys.containsKey(docId)) {
        _questionKeys[docId] = GlobalKey<_QuestionCardState>();
      }

      // QuestionCard 생성
      return QuestionCard(
        key: _questionKeys[docId],
        doc: doc,
        isCompact: true, // 항상 컴팩트 모드 사용
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
    if (mounted) { // 위젯 마운트 상태 확인
      setState(() {
        userChoice = null;
        showExplanation = false;
      });
    }
  }

  // Base64 이미지 확인
  bool isBase64Image(String? data) {
    return data != null && data.startsWith('data:image');
  }

  // Base64 이미지 위젯 생성
  Widget buildImage(String base64String, {bool isOption = false}) {
    try {
      final bytes = base64Decode(base64String.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: isOption ? 120 : double.infinity,
          height: isOption ? 80 : 160,
          errorBuilder: (context, error, stackTrace) {
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

  // 문제 텍스트/이미지 위젯 생성
  Widget buildQuestion(String? question) {
    if (question == null || question.trim().isEmpty) {
      return SizedBox.shrink();
    } else if (isBase64Image(question)) {
      return buildImage(question, isOption: false);
    } else {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(widget.isCompact ? 10 : 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          question,
          style: TextStyle(
            fontSize: widget.isCompact ? 13 : 16,
            height: 1.4,
            color: Colors.black87,
          ),
        ),
      );
    }
  }

  // 선택지 텍스트/이미지 위젯 생성
  Widget buildOption(String? option, bool isSelected, bool isCorrect, bool hasSelected) {
    if (option == null) {
      return Text(
        '옵션 없음',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
          fontSize: widget.isCompact ? 11 : 13,
        ),
      );
    } else if (isBase64Image(option)) {
      return buildImage(option, isOption: true);
    } else {
      String displayText = option;
      Color textColor = Colors.black87;

      if (hasSelected && !widget.isCompact) {
         if (isSelected) {
           textColor = isCorrect ? Colors.green.shade700 : Colors.red.shade700;
         } else if (isCorrect) {
           textColor = Colors.green.shade700;
         }
      }

      return Text(
        displayText,
        style: TextStyle(
          fontSize: widget.isCompact ? 12 : 14,
          color: textColor,
        ),
        maxLines: widget.isCompact ? 3 : null,
        overflow: widget.isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>? ?? {};
    final int correctOption = data['Correct_Option'] as int? ?? 0;
    final String category = data['Category'] as String? ?? '';
    final String year = data['Year'] as String? ?? ''; // 연도 정보 추가

    // 옵션 개수 동적 확인
    int optionCount = 4;
    for (int i = 5; i <= 10; i++) {
      if (data.containsKey('Option$i') && data['Option$i'] != null && data['Option$i'].toString().isNotEmpty) {
        optionCount = i;
      } else {
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // ** Column 높이를 내용에 맞춤 **
        children: [
          // 문제 헤더
          Container(
            padding: EdgeInsets.all(widget.isCompact ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // 문제 번호
                Container(
                  padding: EdgeInsets.symmetric(horizontal: widget.isCompact ? 8 : 10, vertical: widget.isCompact ? 3 : 5),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${data['Question_id'] ?? '?'}',
                    style: TextStyle(
                      fontSize: widget.isCompact ? 11 : 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // 카테고리 및 연도 (컴팩트 모드)
                if (widget.isCompact && (category.isNotEmpty || year.isNotEmpty)) ...[
                  SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${category.isNotEmpty ? category : ''}${category.isNotEmpty && year.isNotEmpty ? ' / ' : ''}${year.isNotEmpty ? year : ''}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                Spacer(),
                // 초기화 버튼
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
                      padding: EdgeInsets.symmetric(horizontal: widget.isCompact ? 4 : 6, vertical: widget.isCompact ? 0 : 2),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // ** SingleChildScrollView 제거하고 Padding 직접 적용 **
          Padding(
            padding: EdgeInsets.all(widget.isCompact ? 8 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ** 내부 Column 높이도 내용에 맞춤 **
              children: [
                // Big Question
                if (data.containsKey('Big_Question') && data['Big_Question'] != null && data['Big_Question'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: widget.isCompact ? 8 : 12),
                    child: Text(
                      data['Big_Question'],
                      style: TextStyle(
                        fontSize: widget.isCompact ? 14 : 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),

                // 부가 질문 (Question)
                if (data.containsKey('Question') && data['Question'] != null && data['Question'].toString().trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: widget.isCompact ? 8 : 12),
                    child: buildQuestion(data['Question']),
                  ),

                SizedBox(height: widget.isCompact ? 6 : 10),

                // 선택지 목록
                Column(
                  mainAxisSize: MainAxisSize.min, // ** 선택지 Column 높이 내용에 맞춤 **
                  children: List.generate(optionCount, (optionIndex) {
                    int optionNumber = optionIndex + 1;
                    String? optionText = data['Option$optionNumber'];
                    bool isSelected = userChoice == optionNumber;
                    bool isCorrect = correctOption == optionNumber;

                    return InkWell(
                      onTap: () {
                        if (userChoice == null && mounted) {
                          setState(() {
                            userChoice = optionNumber;
                            showExplanation = true;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: EdgeInsets.only(bottom: widget.isCompact ? 5 : 8),
                        padding: EdgeInsets.symmetric(horizontal: widget.isCompact ? 10 : 12, vertical: widget.isCompact ? 8 : 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: userChoice != null
                                ? isSelected
                                    ? isCorrect ? Colors.green.shade300 : Colors.red.shade300
                                    : isCorrect ? Colors.green.shade300 : Colors.grey.shade200
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          color: userChoice != null
                              ? isSelected
                                  ? isCorrect ? Colors.green.shade50 : Colors.red.shade50
                                  : isCorrect ? Colors.green.shade50 : Colors.white
                              : Colors.white,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 선택지 번호
                            Container(
                              width: widget.isCompact ? 20 : 24,
                              height: widget.isCompact ? 20 : 24,
                              margin: EdgeInsets.only(right: widget.isCompact ? 8 : 10, top: 1),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: userChoice != null
                                    ? isSelected
                                        ? isCorrect ? Colors.green : Colors.red
                                        : isCorrect ? Colors.green : Colors.grey.shade300
                                    : Colors.grey.shade300,
                              ),
                              child: Text(
                                '$optionNumber',
                                style: TextStyle(
                                  fontSize: widget.isCompact ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: userChoice != null ? (isSelected || isCorrect) ? Colors.white : Colors.black54 : Colors.black54,
                                ),
                              ),
                            ),
                            // 선택지 내용
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
                                  // 컴팩트 모드: 정답/오답 아이콘
                                  if (userChoice != null && widget.isCompact) ...[
                                    SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (isSelected && isCorrect) Icon(Icons.check_circle, color: Colors.green, size: 12)
                                        else if (isSelected && !isCorrect) Icon(Icons.cancel, color: Colors.red, size: 12)
                                        else if (!isSelected && isCorrect) Icon(Icons.radio_button_unchecked, color: Colors.green, size: 12),
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

                // 해설
                if (showExplanation && userChoice != null && data.containsKey('Answer_description') && data['Answer_description'] != null && data['Answer_description'].toString().isNotEmpty) ...[
                  SizedBox(height: widget.isCompact ? 8 : 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(widget.isCompact ? 10 : 14),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.blueGrey.shade700, size: widget.isCompact ? 14 : 18),
                            SizedBox(width: widget.isCompact ? 5 : 8),
                            Text(
                              '해설',
                              style: TextStyle(
                                fontSize: widget.isCompact ? 12 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isCompact ? 5 : 8),
                        Text(
                          data['Answer_description'] ?? '',
                          style: TextStyle(
                            fontSize: widget.isCompact ? 11 : 13,
                            height: 1.4,
                            color: Colors.black.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ], // Padding 내부 Column children 닫기
            ), // Padding 닫기
          ), // 문제 내용 섹션 Column 닫기
        ], // 메인 Column children 닫기
      ), // Container 닫기
    ); // build 메서드 닫기
  }
} // _QuestionCardState 클래스 닫기