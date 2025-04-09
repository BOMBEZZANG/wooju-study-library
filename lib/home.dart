import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'Question_type_Select.dart';
import 'PrivacyPolicyScreen.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> categories = [
    '기사',
    '산업기사',
    '기능사',
    '기능장',
    '컴퓨터자격증',
    '기타'
  ];

  String selectedCategory = '기사';
  String? selectedExamName;
  List<String> examNames = [];
  TextEditingController searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExamNames(selectedCategory);
  }

  Future<void> _loadExamNames(String category) async {
    setState(() {
      examNames = [];
      selectedExamName = null;
      isLoading = true;
    });

    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('exams')
          .where('type', isEqualTo: category)
          .get();

      List<String> names = querySnapshot.docs.map((doc) => doc.id).toList();

      setState(() {
        examNames = names..sort();
        isLoading = false;
        if (examNames.isNotEmpty) {
          selectedExamName = examNames.first;
        }
      });
    } catch (e) {
      print('시험 이름 로딩 오류: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red.shade300,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        title: Text(
          '우주도서관 SPACE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.privacy_tip_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrivacyPolicyScreen(),
                ),
              );
            },
            tooltip: '개인정보처리방침',
          ),
        ],
      ),
      // SingleChildScrollView를 body에 직접 사용하지 않고 내부 레이아웃 수정
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 히어로 섹션 - 높이 축소
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '다양한 국가기술자격 기출문제를 무료로 풀어보세요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),

          // 상단 광고 영역 - 높이 축소
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: 60, // 높이 축소
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Center(
              child: Text(
                'Advertisement',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // 카테고리 필터 - 컴팩트하게 수정
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '자격증 유형',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((category) {
                      bool isSelected = selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedCategory = category;
                            });
                            _loadExamNames(category);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected ? Colors.black : Colors.white,
                            foregroundColor: isSelected ? Colors.white : Colors.black,
                            elevation: 0,
                            side: BorderSide(
                              color: isSelected ? Colors.black : Colors.grey.shade300,
                              width: 1,
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: Size(0, 36),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 검색창 - 마진 축소
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '자격증 검색',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                isDense: true,
              ),
              onSubmitted: (value) {
                print('검색어: $value');
                _searchExams(value);
              },
              onChanged: (value) {
                if (value.length >= 1) {
                  _searchExams(value);
                } else if (value.isEmpty) {
                  _loadExamNames(selectedCategory);
                }
              },
            ),
          ),

          // 시험 목록 섹션 타이틀 - 마진 축소
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  '$selectedCategory 자격증',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${examNames.length}개',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 시험 목록 - Expanded로 변경하여 남은 공간 모두 사용
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : examNames.isEmpty
                    ? Center(
                        child: Text(
                          '해당하는 자격증이 없습니다',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ListView.separated(
                              itemCount: examNames.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(
                                    examNames[index],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    selectedCategory,
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.description_outlined,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios, size: 14),
                                  dense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuestionTypeSelect(
                                          examName: examNames[index],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
      // 하단 저작권 정보는 유지하되 작게 조정
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.grey.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '© 2025 우주도서관 SPACE',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivacyPolicyScreen(),
                  ),
                );
              },
              child: Text(
                '개인정보처리방침',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 검색 기능 구현
  String getChoseong(String str) {
    String result = '';
    for (int i = 0; i < str.length; i++) {
      int code = str.codeUnitAt(i);
      if (code >= 44032 && code <= 55203) {
        int cho = ((code - 44032) / 588).floor();
        result += [
          'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
          'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
        ][cho];
      } else {
        result += str[i];
      }
    }
    return result;
  }

  bool isAllChoseong(String str) {
    const List<String> choseongList = [
      'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
      'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
    ];
    for (int i = 0; i < str.length; i++) {
      if (!choseongList.contains(str[i])) {
        return false;
      }
    }
    return true;
  }

  Future<void> _searchExams(String searchTerm) async {
    if (searchTerm.isEmpty) {
      _loadExamNames(selectedCategory);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot querySnapshot = await _firestore.collection('exams').get();

      List<String> filteredNames = [];
      String searchTermLower = unorm.nfc(searchTerm.toLowerCase().trim());
      String searchTermChoseong = getChoseong(searchTermLower);

      print('검색어: $searchTermLower, 초성: $searchTermChoseong');

      for (var doc in querySnapshot.docs) {
        String docId = doc.id;
        String docIdLower = unorm.nfc(docId.toLowerCase().trim());
        String docIdChoseong = getChoseong(docIdLower);

        print('비교: docId="$docIdLower" (길이: ${docIdLower.length}), searchTerm="$searchTermLower" (길이: ${searchTermLower.length})');
        print('docId 코드 유닛: ${docIdLower.codeUnits}');
        print('searchTerm 코드 유닛: ${searchTermLower.codeUnits}');

        bool normalMatch = docIdLower.contains(searchTermLower);

        bool choseongMatch = false;
        if (searchTerm.length <= 3 && isAllChoseong(searchTerm)) {
          choseongMatch = docIdChoseong.contains(searchTermChoseong);
        }

        if (normalMatch || choseongMatch) {
          filteredNames.add(docId);
          if (normalMatch) {
            print('일반 매치 발견: $docId');
          } else {
            print('초성 매치 발견: $docId');
          }
        } else {
          print('매치 실패: $docId');
        }
      }

      setState(() {
        examNames = filteredNames..sort();
        isLoading = false;
      });

      print('검색 결과: ${examNames.length}개 항목 찾음 (검색어: $searchTerm)');
    } catch (e) {
      print('검색 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('검색하기'),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: '검색어를 입력하세요',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text(
              '취소',
              style: TextStyle(color: Colors.grey[600]),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            child: Text('검색'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              String searchText = searchController.text;
              print('검색어: $searchText');
              _searchExams(searchText);
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