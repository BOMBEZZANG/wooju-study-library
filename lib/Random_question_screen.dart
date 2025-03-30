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

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndQuestions();
  }

  // 카테고리 목록과 랜덤 문제 데이터 로드
  Future<void> _loadCategoriesAndQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      
      // 1. 시험 문서에서 categories 배열 가져오기
      DocumentSnapshot examDoc = await _firestore.collection('exams').doc(widget.examName).get();
      
      if (examDoc.exists && examDoc.data() != null) {
        Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;
        List<dynamic> categoryList = data['categories'] ?? [];
        
        // 카테고리 목록에 '전체' 옵션 추가
        List<String> allCategories = ['전체'];
        allCategories.addAll(categoryList.map((category) => category.toString()));
        
        setState(() {
          categories = allCategories;
          selectedCategory = '전체'; // 기본값으로 '전체' 설정
        });
        
        // 기본값(전체 카테고리)으로 문제 로드
        await _loadRandomQuestions(selectedCategory);
      } else {
        setState(() {
          errorMessage = '시험 정보를 찾을 수 없습니다';
          isLoading = false;
        });
      }
    } catch (e) {
      print('카테고리 및 문제 로딩 오류: $e');
      setState(() {
        errorMessage = '데이터를 로드하는 데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 선택된 카테고리의 랜덤 문제 로드
  Future<void> _loadRandomQuestions(String? category) async {
    setState(() {
      isLoading = true;
      questions = [];
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
        allQuestions.shuffle(Random());
        
        // 최대 maxQuestions개까지만 선택
        List<QueryDocumentSnapshot> randomQuestions = allQuestions.length > maxQuestions 
            ? allQuestions.sublist(0, maxQuestions) 
            : allQuestions;
        
        // Question_id 순으로 정렬 (선택 사항)
        randomQuestions.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          return (aData['Question_id'] as int).compareTo(bData['Question_id'] as int);
        });
        
        setState(() {
          questions = randomQuestions;
          isLoading = false;
        });
      } else {
        setState(() {
          questions = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('랜덤 문제 로딩 오류: $e');
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

  // 새로운 랜덤 문제 세트 로드
  void _loadNewRandomSet() {
    _loadRandomQuestions(selectedCategory);
    
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
        title: Text(
          '',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
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
              _showInfoDialog(context, widget.examName);
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
                  '랜덤 기출문제',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  widget.examName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),
                
                // 카테고리 선택
                Text(
                  '과목 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: Colors.grey.shade900,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != selectedCategory) {
                          setState(() {
                            selectedCategory = newValue;
                          });
                          _loadRandomQuestions(newValue);
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // 새로운 랜덤 문제 세트 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadNewRandomSet,
                    icon: Icon(Icons.shuffle, size: 16),
                    label: Text('새로운 랜덤 문제'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
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
                            ElevatedButton.icon(
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
                                      '랜덤 문제 ${questions.length}개 (${selectedCategory == '전체' ? '전체 과목' : selectedCategory})',
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
              if (year.isNotEmpty) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    year,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
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