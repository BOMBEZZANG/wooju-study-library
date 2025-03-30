import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          '개인정보처리방침',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black54, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '개인정보처리방침',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildSectionTitle('1. 개인정보의 처리 목적'),
            _buildSectionContent(
              '우주도서관 SPACE(이하 "우주도서관")은(는) 다음의 목적을 위하여 개인정보를 처리하고 있으며, 다음의 목적 이외의 용도로는 이용하지 않습니다.\n'
              '- 서비스 제공 및 개선\n'
              '- 사용자 경험 향상\n'
              '- 서비스 이용 기록 분석'
            ),
            
            _buildSectionTitle('2. 개인정보의 처리 및 보유 기간'),
            _buildSectionContent(
              '우주도서관은 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집 시에 동의 받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.'
            ),
            
            _buildSectionTitle('3. 정보주체와 법정대리인의 권리·의무 및 그 행사방법'),
            _buildSectionContent(
              '정보주체는 우주도서관에 대해 언제든지 개인정보 열람, 정정, 삭제, 처리정지 요구 등의 권리를 행사할 수 있습니다. 제1항에 따른 권리 행사는 우주도서관에 대해 「개인정보 보호법」 시행령 제41조제1항에 따라 서면, 전자우편, 모사전송(FAX) 등을 통하여 하실 수 있으며 우주도서관은 이에 대해 지체 없이 조치하겠습니다.'
            ),
            
            _buildSectionTitle('4. 처리하는 개인정보의 항목'),
            _buildSectionContent(
              '우주도서관은 다음의 개인정보 항목을 처리하고 있습니다.\n'
              '- 기기 정보 (모바일, 웹 브라우저)\n'
              '- 서비스 이용 기록\n'
              '- IP 주소'
            ),
            
            _buildSectionTitle('5. 개인정보의 파기'),
            _buildSectionContent(
              '우주도서관은 원칙적으로 개인정보 처리목적이 달성된 경우에는 지체없이 해당 개인정보를 파기합니다. 파기의 절차, 기한 및 방법은 다음과 같습니다.\n'
              '- 파기절차: 이용자가 입력한 정보는 목적 달성 후 별도의 DB에 옮겨져 내부 방침 및 관련 법령에 따라 일정기간 저장된 후 즉시 파기됩니다.\n'
              '- 파기기한: 이용자의 개인정보는 개인정보의 보유기간이 경과된 경우에는 보유기간의 종료일로부터 5일 이내에, 개인정보의 처리 목적 달성, 해당 서비스의 폐지, 사업의 종료 등 그 개인정보가 불필요하게 되었을 때에는 개인정보의 처리가 불필요한 것으로 인정되는 날로부터 5일 이내에 그 개인정보를 파기합니다.'
            ),
            
            _buildSectionTitle('6. 개인정보 자동 수집 장치의 설치·운영 및 거부에 관한 사항'),
            _buildSectionContent(
              '우주도서관은 쿠키 등을 활용하여 이용자에게 개인화된 서비스를 제공하고 있습니다. 쿠키는 웹사이트를 운영하는데 이용되는 서버(http)가 이용자의 컴퓨터 브라우저에게 보내는 소량의 정보이며 이용자들의 컴퓨터에 저장됩니다.\n\n'
              '이용자는 쿠키 설치에 대한 선택권을 가지고 있습니다. 따라서, 이용자는 웹 브라우저에서 옵션을 설정함으로써 모든 쿠키를 허용하거나, 쿠키가 저장될 때마다 확인을 거치거나, 아니면 모든 쿠키의 저장을 거부할 수도 있습니다.'
            ),
            
            _buildSectionTitle('7. 광고 서비스'),
            _buildSectionContent(
              '우주도서관은 Google AdSense를 사용하여 광고를 게재하고 있습니다. Google은 쿠키를 사용하여 이용자가 우주도서관 및 다른 웹사이트를 방문한 내용에 기반하여 광고를 게재합니다.\n\n'
              'Google AdSense의 개인정보 처리에 관한 사항은 Google의 개인정보처리방침을 참고하시기 바랍니다. 사용자는 Google 광고 설정에서 맞춤 광고를 비활성화할 수 있습니다.'
            ),
            
            _buildSectionTitle('8. 개인정보 보호책임자'),
            _buildSectionContent(
              '우주도서관은 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.\n\n'
              '■ 개인정보 보호책임자\n'
              '- 성명: OOO\n'
              '- 연락처: example@example.com'
            ),
            
            _buildSectionTitle('9. 개인정보처리방침 변경'),
            _buildSectionContent(
              '이 개인정보처리방침은 2025년 3월 30일부터 적용됩니다. 법령 및 방침에 따른 변경내용의 추가, 삭제 및 정정이 있는 경우에는 변경사항의 시행 7일 전부터 공지사항을 통하여 고지할 것입니다.'
            ),
            
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }
  
  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.black87,
      ),
    );
  }
}