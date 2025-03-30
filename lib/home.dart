import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'Question_type_Select.dart';

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
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 히어로 섹션
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '우주도서관 SPACE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '다양한 국가기술자격 기출문제를 무료로 풀어보세요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // 카테고리 섹션 타이틀
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
            child: Text(
              '자격증 유형',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          // 카테고리 필터
          Container(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categories.map((category) {
                bool isSelected = selectedCategory == category;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = category;
                    });
                    _loadExamNames(category);
                  },
                  child: Text(category),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.black : Colors.white,
                    foregroundColor: isSelected ? Colors.white : Colors.black,
                    elevation: 0,
                    side: BorderSide(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: 1,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '자격증 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
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

          // 시험 목록 섹션 타이틀
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
            child: Row(
              children: [
                Text(
                  '$selectedCategory 자격증',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${examNames.length}개',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 시험 목록 표 형태
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
                        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                                    ),
                                  ),
                                  subtitle: Text(selectedCategory),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.description_outlined,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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