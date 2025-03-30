import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class StudyNoteScreen extends StatefulWidget {
  final String examName;
  final String category;

  StudyNoteScreen({
    required this.examName,
    required this.category,
  });

  @override
  _StudyNoteScreenState createState() => _StudyNoteScreenState();
}

class _StudyNoteScreenState extends State<StudyNoteScreen> {
  bool isLoading = true;
  Map<String, dynamic>? studyNoteData;
  String errorMessage = '';
  String? appId; // App ID 저장 변수

  @override
  void initState() {
    super.initState();
    _loadStudyNote();
    _loadAppId(); // App ID 로드
  }

  // App ID 로드
  Future<void> _loadAppId() async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      DocumentSnapshot examDoc = await _firestore.collection('exams').doc(widget.examName).get();
      
      if (examDoc.exists && examDoc.data() != null) {
        Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;
        if (data.containsKey('App_Id')) {
          setState(() {
            appId = data['App_Id'];
          });
          print('App ID 로드 완료: $appId');
        }
      }
    } catch (e) {
      print('App ID 로드 오류: $e');
    }
  }

  // App Store로 이동하는 함수
  Future<void> _launchAppStore() async {
    if (appId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('앱 정보를 찾을 수 없습니다'),
          backgroundColor: Colors.red.shade300,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Uri url = Uri.parse('https://apps.apple.com/app/id$appId');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크를 열 수 없습니다'),
            backgroundColor: Colors.red.shade300,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('URL 실행 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('링크를 여는 중 오류가 발생했습니다'),
          backgroundColor: Colors.red.shade300,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadStudyNote() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      
      print('학습 노트 로드 시도: ${widget.examName}/${widget.category}');
      
      // 1. 먼저 기본 형식 시도 (접미사 없음)
      DocumentSnapshot baseDoc = await _firestore
          .collection('exams')
          .doc(widget.examName)
          .collection('study_notes')
          .doc(widget.category)
          .get();
      
      if (baseDoc.exists && baseDoc.data() != null) {
        print('기본 형식 학습 노트 발견');
        Map<String, dynamic> data = baseDoc.data() as Map<String, dynamic>;
        
        // 데이터 구조 확인 - 첫 번째 키가 숫자로 시작하면 새 형식으로 판단
        bool isNewFormat = false;
        if (data.keys.isNotEmpty) {
          String firstKey = data.keys.first;
          isNewFormat = RegExp(r'^\d+\.').hasMatch(firstKey);
        }
        
        if (isNewFormat) {
          print('새 형식 데이터 구조 감지됨');
          setState(() {
            studyNoteData = data;
            isLoading = false;
          });
          return;
        } else if (data.containsKey('topics') && data['topics'] is List) {
          print('기존 형식 데이터 구조 감지됨');
          // 기존 형식 데이터 변환
          Map<String, dynamic> convertedData = _convertTopicsToNewFormat(data['topics']);
          setState(() {
            studyNoteData = convertedData;
            isLoading = false;
          });
          return;
        }
      }
      
      // 2. 루트 컬렉션에서 시도
      print('루트 컬렉션에서 학습 노트 시도');
      
      DocumentSnapshot rootDoc = await _firestore
          .collection('study_notes')
          .doc('${widget.examName}_${widget.category.replaceAll(' ', '')}')
          .get();
      
      if (rootDoc.exists && rootDoc.data() != null) {
        print('루트 컬렉션에서 학습 노트 발견');
        Map<String, dynamic> data = rootDoc.data() as Map<String, dynamic>;
        
        // 데이터 구조 확인
        bool isNewFormat = false;
        if (data.keys.isNotEmpty) {
          String firstKey = data.keys.first;
          isNewFormat = RegExp(r'^\d+\.').hasMatch(firstKey);
        }
        
        if (isNewFormat) {
          setState(() {
            studyNoteData = data;
            isLoading = false;
          });
          return;
        } else if (data.containsKey('topics') && data['topics'] is List) {
          // 기존 형식 데이터 변환
          Map<String, dynamic> convertedData = _convertTopicsToNewFormat(data['topics']);
          setState(() {
            studyNoteData = convertedData;
            isLoading = false;
          });
          return;
        }
      }
      
      // 3. 모든 시도 실패
      print('학습 노트를 찾을 수 없음');
      setState(() {
        errorMessage = '해당 카테고리의 학습 노트를 찾을 수 없습니다.';
        isLoading = false;
      });
    } catch (e) {
      print('학습 노트 로딩 오류: $e');
      setState(() {
        errorMessage = '학습 노트를 불러오는 중 오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  // 기존 형식(topics 배열)을 새 형식(키-값 구조)으로 변환
  Map<String, dynamic> _convertTopicsToNewFormat(List<dynamic> topics) {
    Map<String, dynamic> result = {};
    
    for (var topic in topics) {
      if (topic is Map<String, dynamic>) {
        String title = topic['title'] ?? '';
        String description = topic['description'] ?? '';
        List<dynamic> relatedQuestions = [];
        
        // 관련 문제 추출 시도
        if (description.contains('관련 문제:')) {
          List<String> parts = description.split('관련 문제:');
          description = parts[0].trim();
          
          if (parts.length > 1) {
            String relatedText = parts[1].trim();
            
            // 각 라인에서 연도와 문제 ID 추출
            RegExp regex = RegExp(r'-\s*((\d{4})년\s*(\d{1,2})월)[^\d]*(\d+)');
            Iterable<RegExpMatch> matches = regex.allMatches(relatedText);
            
            for (var match in matches) {
              String date = match.group(1)?.trim() ?? '';
              int questionId = int.tryParse(match.group(4) ?? '0') ?? 0;
              
              if (date.isNotEmpty && questionId > 0) {
                relatedQuestions.add({
                  'date': date,
                  'question_id': questionId
                });
              }
            }
          }
        }
        
        // 변환된 데이터 저장
        result[title] = {
          'description': description,
          'related_questions': relatedQuestions
        };
        
        // 하위 주제가 있으면 추가
        if (topic.containsKey('subtopics') && topic['subtopics'] is Map) {
          Map<String, dynamic> subtopics = topic['subtopics'];
          
          subtopics.forEach((subtopic_title, subtopic_data) {
            if (subtopic_data is Map<String, dynamic>) {
              String subtopic_description = subtopic_data['description'] ?? '';
              List<dynamic> subtopic_related_questions = subtopic_data['related_questions'] ?? [];
              
              result[subtopic_title] = {
                'description': subtopic_description,
                'related_questions': subtopic_related_questions
              };
            }
          });
        }
      }
    }
    
    return result;
  }

  // 정보 다이얼로그 표시
void _showInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('학습 노트 사용 안내'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '주요 기능:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('- 각 주제별로 중요 개념을 학습할 수 있습니다'),
          Text('- 관련 문제로 바로 이동하여 연습할 수 있습니다'),
          Text('- 기출 문제와 연계하여 효율적으로 학습하세요'),
          SizedBox(height: 16),
          Text(
            '학습 팁:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('- 개념을 먼저 이해한 후 문제를 풀어보세요'),
          Text('- 관련 문제를 모두 풀어보며 개념을 확인하세요'),
          Text('- 중요한 내용은 메모해두세요'),
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
          toolbarHeight: 10, // 기본값은 56입니다. 원하는 높이로 조정하세요

        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              _showInfoDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 정보 표시
// 상단 정보 표시
Container(
  width: double.infinity, // 화면 전체 폭으로 확장
  color: Colors.black,
  padding: EdgeInsets.fromLTRB(32, 0, 32, 16), // 패딩 줄이기 (기존 32에서 16으로)
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14, // 글자 크기 줄이기
        ),
      ),
      SizedBox(height: 4), // 간격 줄이기 (기존 8에서 4로)
      Text(
        '학습노트-${widget.category}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24, // 글자 크기 줄이기 (기존 28에서 24로)
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 4), // 간격 줄이기
      Text(
        widget.examName,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14, // 글자 크기 줄이기
        ),
      ),
    ],
  ),
),

          // 앱 다운로드 배너
// 앱 다운로드 배너
if (appId != null)
  Container(
    width: double.infinity,
    margin: EdgeInsets.fromLTRB(32, 16, 32, 16), // 마진 줄이기
    child: ElevatedButton.icon(
      onPressed: _launchAppStore,
      icon: Icon(Icons.download, size: 18), // 아이콘 크기 줄이기
      label: Text('iOS 앱으로 오프라인에서도 학습하기'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20), // 패딩 줄이기
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  ),

          // 학습 노트 컨텐츠
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
                          '학습 노트를 불러오는 중입니다...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                errorMessage,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadStudyNote,
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
                    : _buildStudyNoteContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyNoteContent() {
    if (studyNoteData == null || studyNoteData!.isEmpty) {
      return Center(
        child: Text(
          '학습 노트 데이터가 없습니다.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // 주제 정렬 (번호순)
    List<String> topics = studyNoteData!.keys.toList();
    topics.sort((a, b) {
      // 번호 추출 시도 (예: "1. 주제명" -> 1)
      RegExp numRegex = RegExp(r'^(\d+)\.');
      var matchA = numRegex.firstMatch(a);
      var matchB = numRegex.firstMatch(b);
      
      if (matchA != null && matchB != null) {
        int numA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
        int numB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
        return numA.compareTo(numB);
      }
      
      // 번호가 없으면 그냥 문자열 비교
      return a.compareTo(b);
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 학습 노트 소개
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            margin: EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학습 가이드',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '이 학습 노트는 ${widget.category}에 관한 주요 개념을 담고 있습니다. 각 개념을 이해하고 관련 문제를 풀어보세요.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // 주제 목록
          ...topics.map((topicTitle) => _buildTopicSection(topicTitle, studyNoteData![topicTitle])).toList(),
        ],
      ),
    );
  }

  Widget _buildTopicSection(String title, Map<String, dynamic> topicData) {
    String description = topicData['description'] ?? '';
    List<dynamic> relatedQuestions = topicData['related_questions'] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 24),
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
          // 주제 제목
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          
          // 주제 설명
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
          
          // 관련 문제
          if (relatedQuestions.isNotEmpty)
            _buildRelatedQuestions(relatedQuestions),
        ],
      ),
    );
  }

  Widget _buildRelatedQuestions(List<dynamic> relatedQuestions) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: Colors.amber.shade700,
              ),
              SizedBox(width: 8),
              Text(
                '관련 문제',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: relatedQuestions.map<Widget>((question) {
              if (question is Map) {
                String date = question['date'] ?? '';
                int questionId = question['question_id'] ?? 0;
                
                return ElevatedButton.icon(
                  onPressed: () {
                    _showQuestionDialog(date, questionId);
                  },
                  icon: Icon(
                    Icons.description_outlined,
                    size: 16,
                  ),
                  label: Text('$date $questionId번'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 문제 표시 다이얼로그를 호출하는 함수
  void _showQuestionDialog(String date, int questionId) {
    // 연도 정보에서 "년"을 기준으로 분리하여 Year 값과 일치하는지 확인
    String year = date.replaceAll(' ', '');
    
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
              SizedBox(height: 16),
              Text('문제를 불러오는 중입니다...'),
            ],
          ),
        );
      },
    );
    
    // Firestore에서 해당 문제 찾기
    FirebaseFirestore.instance
        .collection('exams')
        .doc(widget.examName)
        .collection('questions')
        .where('Year', isEqualTo: year)
        .where('Question_id', isEqualTo: questionId)
        .get()
        .then((querySnapshot) {
          // 로딩 다이얼로그 닫기
          Navigator.of(context).pop();
          
          if (querySnapshot.docs.isNotEmpty) {
            // 첫 번째 일치하는 문서 가져오기
            var doc = querySnapshot.docs.first;
            var data = doc.data();
            print('문제 데이터: ${data.keys.join(', ')}');
            print('Big_Question: ${data['Big_Question']}');
            // 문제 다이얼로그 표시
            _showQuestionContentDialog(data);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('해당 문제를 찾을 수 없습니다'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red.shade400,
              ),
            );
          }
        })
        .catchError((error) {
          // 로딩 다이얼로그 닫기
          Navigator.of(context).pop();
          
          print('문제 검색 오류: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('문제를 검색하는 중 오류가 발생했습니다'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade400,
            ),
          );
        });
  }

  // 문제 내용을 보여주는 새로운 다이얼로그 함수
  void _showQuestionContentDialog(Map<String, dynamic> data) {
    int correctOption = data['Correct_Option'] ?? 0;
    String category = data['Category'] ?? '';
    String year = data['Year'] ?? '';
    String question = data['Question'] ?? '';
    final String bigQuestion = data['Big_Question'] ?? '문제 ${data['Question_id']}';
    String answerDescription = data['Answer_description'] ?? '해설이 제공되지 않았습니다.';
    
    // 옵션 개수 확인
    int optionCount = 4; // 기본 옵션 개수
    if (data.containsKey('Option5') && data['Option5'] != null) {
      optionCount = 5;
    }
    
    // 사용자 선택 상태 (모달에서 사용할 로컬 상태)
    int? userChoice;
    bool showExplanation = false;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // 이미지인지 확인하는 함수
            bool isBase64Image(String? data) {
              return data != null && data.startsWith('data:image');
            }
            
            // 이미지 위젯 생성 함수
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
            
            // 문제 텍스트 또는 이미지 생성
            Widget buildQuestion(String? question) {
              if (question == null || question.trim().isEmpty) {
                return SizedBox.shrink(); // 문제가 없으면 빈 공간 반환
              } else if (isBase64Image(question)) {
                return buildImage(question, isOption: false);
              } else {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    question,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                );
              }
            }
            
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
    Color textColor = Colors.black87;
    FontWeight weight = FontWeight.normal;
    
    if (hasSelected) {
      if (isSelected) {
        if (isCorrect) {
          displayText += ' (정답)';
          textColor = Colors.green.shade700;
          weight = FontWeight.w600;
        } else {
          displayText += ' (오답)';
          textColor = Colors.red.shade700;
          weight = FontWeight.w600;
        }
      } else if (isCorrect) {
        displayText += ' (정답)';
        textColor = Colors.green.shade700;
        weight = FontWeight.w600;
      } else {
        textColor = Colors.grey.shade600;
      }
    }
    
    return Text(
      displayText,
      style: TextStyle(
        color: textColor,
        fontWeight: weight,
        fontSize: 15,
      ),
    );
  }
}

return Dialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: Container(
    width: MediaQuery.of(context).size.width * 0.9,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.8,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 헤더 부분
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bigQuestion,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
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
                  SizedBox(width: 8),
                  if (category.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (year.isNotEmpty)
                    SizedBox(width: 8),
                  if (year.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        year,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // 문제 내용 부분
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildQuestion(question),
                SizedBox(height: 24),
                Column(
                  children: List.generate(optionCount, (optionIndex) {
                    int optionNumber = optionIndex + 1;
                    String? optionText = data['Option$optionNumber'];
                    bool isSelected = userChoice == optionNumber;
                    bool isCorrect = correctOption == optionNumber;
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
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
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            userChoice = optionNumber;
                            showExplanation = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
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
                              SizedBox(width: 16),
                              Expanded(
                                child: buildOption(
                                  optionText,
                                  isSelected,
                                  isCorrect,
                                  userChoice != null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (showExplanation && userChoice != null) ...[
                  SizedBox(height: 24),
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
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '해설',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          answerDescription,
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
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
        
        // 하단 버튼 영역
        Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (userChoice != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      userChoice = null;
                      showExplanation = false;
                    });
                  },
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('다시 풀기'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                  ),
                )
              else
                SizedBox(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('닫기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
          });
      }
    );

      }
}