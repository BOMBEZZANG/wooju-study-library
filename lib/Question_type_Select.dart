import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Question_Screen.dart';
import 'Subject_Question_Screen.dart';
import 'Random_question_screen.dart';
import 'StudyNoteScreen.dart'; // StudyNoteScreen 추가

class QuestionTypeSelect extends StatefulWidget {
  final String examName;

  QuestionTypeSelect({required this.examName});

  @override
  _QuestionTypeSelectState createState() => _QuestionTypeSelectState();
}

class _QuestionTypeSelectState extends State<QuestionTypeSelect> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> years = [];
  List<String> categories = [];
  bool isLoadingYears = false;
  bool isLoadingCategories = false;
  bool isLoadingStudyNotes = false;
  String errorMessage = '';
  String? appId; // Apple App ID 저장 변수
  
  // 선택된 섹션
  String selectedSection = '연도별 문제풀기';
  
  // 학습 노트가 있는 카테고리 목록
  Map<String, String> studyNoteRefs = {};

  @override
  void initState() {
    super.initState();
    _loadYears();
    _loadCategories();
    _loadStudyNoteRefs();
    _loadAppId(); // App ID 로드
  }

  // App ID 로드
  Future<void> _loadAppId() async {
    try {
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

  Future<void> _loadYears() async {
    if (years.isNotEmpty) return;

    setState(() {
      isLoadingYears = true;
      errorMessage = '';
    });

    try {
      print('연도 로딩 시작: ${widget.examName}');
      
      // 1. 시험 문서에서 years 배열 가져오기
      DocumentSnapshot examDoc = await _firestore.collection('exams').doc(widget.examName).get();
      
      if (examDoc.exists && examDoc.data() != null) {
        Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;
        List<dynamic> yearList = data['years'] ?? [];
        
        if (yearList.isNotEmpty) {
          print('시험 문서에서 찾은 연도: $yearList');
          setState(() {
            years = yearList.map((year) => year.toString()).toList()..sort((a, b) => b.compareTo(a)); // 내림차순 정렬 (최신 연도 우선)
          });
        } else {
          print('시험 문서에 years 필드가 비어있습니다. questions 컬렉션에서 Year 필드 검색');
          
          // 2. years 필드가 비어있으면 questions 컬렉션에서 모든 고유 Year 값 가져오기
          QuerySnapshot questionsSnapshot = await _firestore
              .collection('exams')
              .doc(widget.examName)
              .collection('questions')
              .get();
              
          print('questions 컬렉션에서 ${questionsSnapshot.docs.length}개의 문서 찾음');
          
          Set<String> uniqueYears = {};
          for (var doc in questionsSnapshot.docs) {
            var docData = doc.data() as Map<String, dynamic>;
            if (docData.containsKey('Year') && docData['Year'] != null) {
              uniqueYears.add(docData['Year'].toString());
              print('찾은 Year 값: ${docData['Year']}');
            }
          }
          
          setState(() {
            years = uniqueYears.toList()..sort((a, b) => b.compareTo(a)); // 내림차순 정렬
          });
          
          // Firebase에 years 필드 업데이트
          if (years.isNotEmpty) {
            await _firestore.collection('exams').doc(widget.examName).update({
              'years': years
            });
            print('Firestore years 필드 업데이트됨: $years');
          }
        }
      } else {
        print('시험 문서를 찾을 수 없음: ${widget.examName}');
        setState(() {
          errorMessage = '시험 정보를 찾을 수 없습니다';
        });
      }
    } catch (e) {
      print('연도 로딩 오류: $e');
      setState(() {
        errorMessage = '연도 데이터를 로드하는 데 실패했습니다: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('연도 데이터를 로드하는 데 실패했습니다'),
          backgroundColor: Colors.red.shade300,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoadingYears = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    if (categories.isNotEmpty) return;

    setState(() {
      isLoadingCategories = true;
    });

    try {
      print('카테고리 로딩 시작: ${widget.examName}');
      
      // 1. 시험 문서에서 categories 배열 가져오기
      DocumentSnapshot doc = await _firestore.collection('exams').doc(widget.examName).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> categoryList = data['categories'] ?? [];
        
        if (categoryList.isNotEmpty) {
          print('시험 문서에서 찾은 카테고리: $categoryList');
          setState(() {
            categories = categoryList.map((category) => category.toString()).toList()..sort();
          });
        } else {
          print('시험 문서에 categories 필드가 비어있습니다. questions 컬렉션에서 Category 필드 검색');
          
          // 2. categories 필드가 비어있으면 questions 컬렉션에서 모든 고유 Category 값 가져오기
          QuerySnapshot questionsSnapshot = await _firestore
              .collection('exams')
              .doc(widget.examName)
              .collection('questions')
              .get();
              
          print('questions 컬렉션에서 ${questionsSnapshot.docs.length}개의 문서 찾음');
          
          Set<String> uniqueCategories = {};
          for (var doc in questionsSnapshot.docs) {
            var docData = doc.data() as Map<String, dynamic>;
            if (docData.containsKey('Category') && docData['Category'] != null) {
              uniqueCategories.add(docData['Category'].toString());
              print('찾은 Category 값: ${docData['Category']}');
            }
          }
          
          setState(() {
            categories = uniqueCategories.toList()..sort();
          });
          
          // Firebase에 categories 필드 업데이트
          if (categories.isNotEmpty) {
            await _firestore.collection('exams').doc(widget.examName).update({
              'categories': categories
            });
            print('Firestore categories 필드 업데이트됨: $categories');
          }
        }
      } else {
        print('시험 문서를 찾을 수 없음: ${widget.examName}');
      }
    } catch (e) {
      print('과목 로딩 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('과목 데이터를 로드하는 데 실패했습니다'),
          backgroundColor: Colors.red.shade300,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        isLoadingCategories = false;
      });
    }
  }

  // 학습 노트 참조 로드 함수
  Future<void> _loadStudyNoteRefs() async {
    setState(() {
      isLoadingStudyNotes = true;
    });

    try {
      print('학습 노트 참조 로딩 시작: ${widget.examName}');
      
      // 1. 먼저 시험 문서에서 study_notes_refs 필드 확인
      DocumentSnapshot doc = await _firestore.collection('exams').doc(widget.examName).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data.containsKey('study_notes_refs')) {
          Map<String, dynamic> refs = data['study_notes_refs'];
          
          Map<String, String> mappedRefs = {};
          refs.forEach((key, value) {
            mappedRefs[key] = value.toString();
          });
          
          setState(() {
            studyNoteRefs = mappedRefs;
          });
          
          print('학습 노트 참조 로드 완료: ${studyNoteRefs.length}개');
          return;
        }
      }
      
      // 2. study_notes_refs 필드가 없으면 서브컬렉션 확인
      QuerySnapshot studyNotesSnapshot = await _firestore
          .collection('exams')
          .doc(widget.examName)
          .collection('study_notes')
          .get();
      
      if (studyNotesSnapshot.docs.isNotEmpty) {
        Map<String, String> refs = {};
        
        for (var doc in studyNotesSnapshot.docs) {
          refs[doc.id] = 'study_notes/${doc.id}';
        }
        
        setState(() {
          studyNoteRefs = refs;
        });
        
        print('서브컬렉션에서 학습 노트 ${refs.length}개 발견');
        
        // 파이어스토어에 참조 추가
        if (refs.isNotEmpty) {
          await _firestore.collection('exams').doc(widget.examName).update({
            'study_notes_refs': refs
          }).then((_) {
            print('study_notes_refs 필드 생성 완료');
          }).catchError((e) {
            print('study_notes_refs 필드 생성 실패: $e');
          });
        }
        
        return;
      }
      
      print('시험에 학습 노트가 없습니다');
    } catch (e) {
      print('학습 노트 참조 로딩 오류: $e');
    } finally {
      setState(() {
        isLoadingStudyNotes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        centerTitle: false,
        // title: Text(
        //   widget.examName,
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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 소개 배너
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.examName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '다양한 방식으로 기출문제를 풀어보세요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 앱 다운로드 배너
          if (appId != null)
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(32, 32, 32, 8),
              child: ElevatedButton.icon(
                onPressed: _launchAppStore,
                icon: Icon(Icons.download, size: 20),
                label: Text('iOS 앱으로 오프라인에서도 학습하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),

          SizedBox(height: 24),

          // 섹션 선택 탭
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSectionTab('연도별 문제풀기', Icons.calendar_today),
                  SizedBox(width: 16),
                  _buildSectionTab('과목별 문제풀기', Icons.category),
                  SizedBox(width: 16),
                  _buildSectionTab('랜덤 문제풀기', Icons.shuffle),
                  SizedBox(width: 16),
                  _buildSectionTab('학습 노트', Icons.menu_book),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // 선택된 섹션에 따른 컨텐츠
          _buildSectionTitle(),

          Expanded(
            child: _buildSectionContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTab(String title, IconData icon) {
    bool isSelected = selectedSection == title;
    
    return InkWell(
      onTap: () {
        setState(() {
          selectedSection = title;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.grey,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    String title = '';
    String subtitle = '';
    
    switch (selectedSection) {
      case '연도별 문제풀기':
        title = '연도별 문제';
        subtitle = '연도별로 기출문제를 풀어보세요';
        break;
      case '과목별 문제풀기':
        title = '과목별 문제';
        subtitle = '과목별로 기출문제를 풀어보세요';
        break;
      case '랜덤 문제풀기':
        title = '랜덤 문제';
        subtitle = '무작위로 선별된 문제를 풀어보세요';
        break;
      case '학습 노트':
        title = '학습 노트';
        subtitle = '핵심 개념을 정리한 학습 노트를 확인하세요';
        break;
    }
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (selectedSection) {
      case '연도별 문제풀기':
        return _buildYearsList();
      case '과목별 문제풀기':
        return _buildCategoriesList();
      case '랜덤 문제풀기':
        return _buildRandomQuizSection();
      case '학습 노트':
        return _buildStudyNotesList();
      default:
        return _buildYearsList();
    }
  }
Widget _buildRandomQuizSection() {
  return SingleChildScrollView(  // 스크롤 가능하도록 감싸기
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '랜덤 문제 풀기',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                '모든 연도/과목에서 랜덤 문제 풀기',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text('다양한 유형의 문제로 실력을 점검해보세요'),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shuffle,
                  color: Colors.blue.shade700,
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RandomQuestionScreen(
                      examName: widget.examName,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24),
          Text(
            '학습 팁',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          _buildTipCard(
            '랜덤 문제는 실전 감각을 키우는 데 효과적입니다',
            Icons.lightbulb_outline,
          ),
          SizedBox(height: 12),
          _buildTipCard(
            '시간을 정해놓고 풀면 실전에 더 도움이 됩니다',
            Icons.access_time,
          ),
          SizedBox(height: 12),
          _buildTipCard(
            '오답노트를 작성하여 부족한 부분을 확인하세요',
            Icons.note_alt_outlined,
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTipCard(String tip, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.blue.shade700,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearsList() {
    if (isLoadingYears) {
      return _buildLoadingWidget();
    }

    if (years.isEmpty) {
      return _buildEmptyStateWidget('연도', errorMessage);
    }

    return ListView.separated(
      padding: EdgeInsets.all(32),
      itemCount: years.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        return _buildListItem(
          title: years[index],
          subtitle: '${widget.examName} ${years[index]} 기출문제',
          icon: Icons.calendar_today,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestionScreen(
                  examName: widget.examName,
                  year: years[index],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoriesList() {
    if (isLoadingCategories) {
      return _buildLoadingWidget();
    }

    if (categories.isEmpty) {
      return _buildEmptyStateWidget('과목', '');
    }

    return ListView.separated(
      padding: EdgeInsets.all(32),
      itemCount: categories.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        return _buildListItem(
          title: categories[index],
          subtitle: '${categories[index]} 관련 문제',
          icon: Icons.category,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectQuestionScreen(
                  examName: widget.examName,
                  subjectName: categories[index],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudyNotesList() {
    if (isLoadingStudyNotes) {
      return _buildLoadingWidget();
    }

    // 1. study_notes_refs에서 참조를 찾은 경우
    if (studyNoteRefs.isNotEmpty) {
      // 카테고리와 동일한 순서로 학습 노트 정렬
      List<String> availableCategories = [];
      
      // 먼저 categories에 있는 항목들 추가
      for (String category in categories) {
        if (studyNoteRefs.containsKey(category)) {
          availableCategories.add(category);
        }
      }
      
      // 그 외 추가 학습 노트가 있으면 추가
      for (String key in studyNoteRefs.keys) {
        if (!availableCategories.contains(key)) {
          availableCategories.add(key);
        }
      }
      
      return ListView.separated(
        padding: EdgeInsets.all(32),
        itemCount: availableCategories.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          return _buildListItem(
            title: availableCategories[index],
            subtitle: '${availableCategories[index]} 학습 노트',
            icon: Icons.menu_book,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudyNoteScreen(
                    examName: widget.examName,
                    category: availableCategories[index],
                  ),
                ),
              );
            },
          );
        },
      );
    }
    
    // 2. 서브컬렉션을 직접 확인
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
        .collection('exams')
        .doc(widget.examName)
        .collection('study_notes')
        .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }
        
        if (snapshot.hasError) {
          return _buildComingSoonWidget('학습 노트');
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildComingSoonWidget('학습 노트');
        }
        
        List<String> availableNotes = snapshot.data!.docs.map((doc) => doc.id).toList();
        
        return ListView.separated(
          padding: EdgeInsets.all(32),
          itemCount: availableNotes.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
          itemBuilder: (context, index) {
            return _buildListItem(
              title: availableNotes[index],
              subtitle: '${availableNotes[index]} 학습 노트',
              icon: Icons.menu_book,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudyNoteScreen(
                      examName: widget.examName,
                      category: availableNotes[index],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildListItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.blue.shade700,
            size: 20,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
      ),
    );
  }
Widget _buildLoadingWidget() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
          strokeWidth: 2,
        ),
        SizedBox(height: 16),
        Text(
          '데이터를 불러오는 중입니다...',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyStateWidget(String type, String error) {
  return Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[400],
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            '사용 가능한 $type 데이터가 없습니다',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (error.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: type == '연도' ? _loadYears : _loadCategories,
            child: Text('다시 시도'),
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
    ),
  );
}

Widget _buildComingSoonWidget(String feature) {
  return Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time,
            color: Colors.grey[400],
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            '$feature 기능 준비 중입니다',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '더 나은 서비스로 곧 찾아뵙겠습니다',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
}