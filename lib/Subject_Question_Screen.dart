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

  @override
  void initState() {
    super.initState();
    _loadYearsAndQuestions();
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
      DocumentSnapshot examDoc = await _firestore.collection('exams').doc(widget.examName).get();
      
      if (examDoc.exists && examDoc.data() != null) {
        Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;
        List<dynamic> yearList = data['years'] ?? [];
        
        if (yearList.isNotEmpty) {
          // 연도 목록 정렬 (내림차순 - 최신 연도가 먼저 오도록)
          List<String> sortedYears = yearList.map((year) => year.toString()).toList();
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
      questions = [];
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      print('로드 시도: exam=${widget.examName}, subject=${widget.subjectName}, year=$year');

      // 새 구조에서는 questions 컬렉션에서 Category와 Year 필드로 필터링
      final QuerySnapshot snapshot = await _firestore
          .collection('exams')
          .doc(widget.examName)
          .collection('questions')
          .where('Category', isEqualTo: widget.subjectName)
          .where('Year', isEqualTo: year)
          .orderBy('Question_id')
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
                  key.currentState!.resetQuestion();
                }
              });
              Navigator.pop(context);

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
        // title: Text(
        //   widget.subjectName,
        //   style: TextStyle(
        //     color: Colors.white,
        //     fontWeight: FontWeight.w400,
        //     fontSize: 20,
        //   ),
        // ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetAllQuestions,
            tooltip: '모든 문제 초기화',
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              _showInfoDialog(context, widget.examName, widget.subjectName);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 정보 표시
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.subjectName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                
                // 연도 선택 드롭다운
                // 연도 선택 드롭다운
if (years.isNotEmpty) ...[
  Row(
    children: [
      Icon(
        Icons.calendar_today,
        color: Colors.white,
        size: 18,
      ),
      SizedBox(width: 8),
      Text(
        '연도 선택:',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
  SizedBox(height: 8),
  Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedYear,
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: Icon(Icons.keyboard_arrow_down, color: Colors.black),
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
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
            _loadQuestions(newValue);
          }
        },
      ),
    ),
  ),
],
              ],
            ),
          ),

          // 문제 컨텐츠
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
                        SizedBox(height: 16),
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
                              size: 64,
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
                            ElevatedButton.icon(
                              onPressed: () {
                                if (selectedYear != null) {
                                  _loadQuestions(selectedYear!);
                                } else {
                                  _loadYearsAndQuestions();
                                }
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
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // 문제 개요 정보
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade600,
                                    size: 24,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      '${widget.subjectName} (${selectedYear}) - ${questions.length}문항',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _resetAllQuestions,
                                    icon: Icon(Icons.refresh, size: 16),
                                    label: Text('초기화'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // 모든 문제 표시
                            ...questions.map((doc) {
                              final docId = doc.id;
                              if (!_questionKeys.containsKey(docId)) {
                                _questionKeys[docId] = GlobalKey<_QuestionCardState>();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 32.0),
                                child: QuestionCard(
                                  key: _questionKeys[docId],
                                  doc: doc,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

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
}

// 개별 문제 카드 위젯
class QuestionCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;

  QuestionCard({Key? key, required this.doc}) : super(key: key);

  @override
  _QuestionCardState createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  int? userChoice;
  bool showExplanation = false;

  // 문제 초기화 메서드
  void resetQuestion() {
    setState(() {
      userChoice = null;
      showExplanation = false;
    });
  }

  // Base64 이미지인지 확인
  bool isBase64Image(String? data) {
    return data != null && data.startsWith('data:image');
  }

  // Base64 데이터를 이미지로 변환
  Widget buildImage(String base64String, {bool isOption = false}) {
    try {
      final bytes = base64Decode(base64String.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: isOption ? 200 : double.infinity,
          height: isOption ? 120 : 250,
        ),
      );
    } catch (e) {
      return Center(
        child: Text(
          '이미지를 표시할 수 없습니다',
          style: TextStyle(color: Colors.red.shade400),
        ),
      );
    }
  }

  // Question 위젯 생성
  Widget buildQuestion(String? question) {
    if (question == null) {
      return SizedBox.shrink();
    } else if (isBase64Image(question)) {
      return buildImage(question, isOption: false);
    } else {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          question,
          style: TextStyle(
            fontSize: 18,
            height: 1.5,
            color: Colors.black87,
          ),
        ),
      );
    }
  }

  // Option 위젯 생성
  Widget buildOption(String? option, bool isSelected, bool isCorrect, bool hasSelected) {
    if (option == null) {
      return Text(
        '옵션 없음',
        style: TextStyle(
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (isBase64Image(option)) {
      return buildImage(option, isOption: true);
    } else {
      String displayText = option;
      
      return Text(
        displayText,
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.doc.data() as Map<String, dynamic>;
    int correctOption = data['Correct_Option'] ?? 0;
    String category = data['Category'] ?? '';
    String year = data['Year'] ?? '';
    
    // 옵션 개수 확인 (Option5가 있는지 체크)
    int optionCount = 4; // 기본 옵션 개수
    if (data.containsKey('Option5') && data['Option5'] != null) {
      optionCount = 5; // Option5가 존재하면 5개로 설정
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 문제 헤더 섹션
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Q${data['Question_id']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                if (category.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                Spacer(),
                if (userChoice != null)
                  TextButton.icon(
                    onPressed: resetQuestion,
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text('초기화'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          
          // 문제 내용 섹션
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 문제 제목
                if (data.containsKey('Big_Question') && data['Big_Question'] != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Text(
                      data['Big_Question'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                
                // 문제 내용
                buildQuestion(data['Question']),
                SizedBox(height: 24),
                
                // 선택지
                Column(
                  children: List.generate(optionCount, (optionIndex) {
                    int optionNumber = optionIndex + 1;
                    String? optionText = data['Option$optionNumber'];
                    bool isSelected = userChoice == optionNumber;
                    bool isCorrect = correctOption == optionNumber;

                    return InkWell(
                      onTap: () {
                        if (userChoice == null) {
                          setState(() {
                            userChoice = optionNumber;
                            showExplanation = true;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: userChoice != null
                                ? isSelected
                                    ? isCorrect
                                        ? Colors.green.shade300
                                        : Colors.red.shade300
                                    : isCorrect
                                        ? Colors.green.shade300
                                        : Colors.grey.shade200
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          color: userChoice != null
                              ? isSelected
                                  ? isCorrect
                                      ? Colors.green.shade50
                                      : Colors.red.shade50
                                  : isCorrect
                                      ? Colors.green.shade50
                                      : Colors.white
                              : Colors.white,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              margin: EdgeInsets.only(right: 16, top: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: userChoice != null
                                    ? isSelected
                                        ? isCorrect
                                            ? Colors.green
                                            : Colors.red
                                        : isCorrect
                                            ? Colors.green
                                            : Colors.grey.shade200
                                    : Colors.grey.shade200,
                                border: Border.all(
                                  color: userChoice != null
                                      ? isSelected
                                          ? isCorrect
                                              ? Colors.green
                                              : Colors.red
                                          : isCorrect
                                              ? Colors.green
                                              : Colors.grey.shade400
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${optionIndex + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: userChoice != null
                                      ? isSelected || isCorrect
                                          ? Colors.white
                                          : Colors.grey.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
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
                                  if (userChoice != null) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (isSelected && isCorrect)
                                          Text(
                                            '정답입니다!',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        else if (isSelected && !isCorrect)
                                          Text(
                                            '오답입니다',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        else if (!isSelected && isCorrect)
                                          Text(
                                            '정답',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                if (showExplanation && userChoice != null && data.containsKey('Answer_description') && data['Answer_description'] != null) ...[
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.amber.shade700,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '해설',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          data['Answer_description'] ?? '해설이 제공되지 않았습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}