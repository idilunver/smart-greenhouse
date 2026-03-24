import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/ai_service.dart';

// Tek bir sohbeti temsil eden model
class Conversation {
  final String id;
  String title;
  final List<Map<String, String>> messages;

  Conversation({required this.id, required this.title, required this.messages});
}

class AIChatAnalysisPage extends StatefulWidget {
  const AIChatAnalysisPage({super.key});
  @override
  State<AIChatAnalysisPage> createState() => _AIChatAnalysisPageState();
}

class _AIChatAnalysisPageState extends State<AIChatAnalysisPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  // Tüm sohbetler listesi
  final List<Conversation> _conversations = [];
  // Şu an aktif olan sohbetin index'i
  int _activeConversationIndex = 0;

  @override
  void initState() {
    super.initState();
    // Uygulama açılınca bir adet varsayılan sohbet oluştur
    _createNewConversation();
  }

  void _createNewConversation() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newConv = Conversation(
      id: newId,
      title: "Sohbet ${_conversations.length + 1}",
      messages: [
        {'role': 'ai', 'text': 'Merhaba! Ben Sera Asistanınız. Bitkileriniz hakkında ne bilmek istersiniz?'}
      ],
    );
    setState(() {
      _conversations.add(newConv);
      _activeConversationIndex = _conversations.length - 1;
    });
  }

  void _deleteConversation(int index) {
    if (_conversations.length == 1) {
      // Son sohbet silinirse yeni bir tane oluştur
      setState(() {
        _conversations.clear();
      });
      _createNewConversation();
      return;
    }
    setState(() {
      _conversations.removeAt(index);
      // Silinen eleman aktif indexten önce veya aynısıysa index'i düzelt
      if (_activeConversationIndex >= _conversations.length) {
        _activeConversationIndex = _conversations.length - 1;
      }
    });
  }

  void _switchConversation(int index) {
    setState(() {
      _activeConversationIndex = index;
    });
  }

  void _handleSendMessage() async {
    if (_controller.text.isEmpty || _isLoading) return;
    if (_conversations.isEmpty) return;

    String userMsg = _controller.text;
    final activeConv = _conversations[_activeConversationIndex];

    // Sohbet başlığını ilk mesaja göre güncelle
    if (activeConv.messages.length == 1) {
      activeConv.title = userMsg.length > 30 ? "${userMsg.substring(0, 30)}..." : userMsg;
    }

    setState(() {
      activeConv.messages.add({'role': 'user', 'text': userMsg});
      _isLoading = true;
      _controller.clear();
    });

    try {
      final snapshot = await FirebaseDatabase.instance.ref("Greenhouse/Sensors").get();
      Map sensorData = (snapshot.value as Map?) ?? {};

      String aiResponse = await AIService.getChatResponse(userMsg, sensorData);

      setState(() {
        activeConv.messages.add({'role': 'ai', 'text': aiResponse});
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("_handleSendMessage HATA: $e");
      setState(() {
        activeConv.messages.add({'role': 'ai', 'text': 'Sistem Hatası: Lütfen bağlantınızı kontrol edin.'});
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeConv = _conversations.isNotEmpty ? _conversations[_activeConversationIndex] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 700;

        return Scaffold(
          appBar: AppBar(
            title: const Text("🤖 AI Sera Danışmanı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            leading: isMobile 
              ? Builder(builder: (context) => IconButton(
                  icon: const Icon(Icons.history_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ))
              : null,
            actions: [
              if (!isMobile)
                TextButton.icon(
                  onPressed: _createNewConversation,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Yeni Sohbet"),
                  style: TextButton.styleFrom(foregroundColor: Colors.green[800]),
                ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: isMobile ? _buildSidebar(isMobile: true) : null,
          body: Row(
            children: [
              // --- SOL PANEL: Sohbet Listesi (Sadece Web'de Sabit) ---
              if (!isMobile) _buildSidebar(isMobile: false),

              // --- SAĞ PANEL: Aktif Sohbet ---
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: activeConv == null
                      ? const Center(child: Text("Yeni bir sohbet başlatın"))
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                itemCount: activeConv.messages.length,
                                itemBuilder: (context, index) {
                                  bool isUser = activeConv.messages[index]['role'] == 'user';
                                  return Align(
                                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      constraints: BoxConstraints(maxWidth: isMobile ? constraints.maxWidth * 0.8 : 600),
                                      decoration: BoxDecoration(
                                        color: isUser ? Colors.green[700] : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: Radius.circular(isUser ? 20 : 4),
                                          bottomRight: Radius.circular(isUser ? 4 : 20),
                                        ),
                                        boxShadow: [
                                          if (isUser) BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activeConv.messages[index]['text']!,
                                            style: TextStyle(
                                              color: isUser ? Colors.white : Colors.black87,
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_isLoading)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: const LinearProgressIndicator(minHeight: 3, backgroundColor: Color(0xFFF1F5F9)),
                                ),
                              ),
                            _buildInputArea(isMobile),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar({required bool isMobile}) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: isMobile ? 16 : 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          border: isMobile ? null : Border(right: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text("Sohbet Geçmişi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(onPressed: _createNewConversation, icon: const Icon(Icons.add_comment_outlined, color: Colors.green)),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text("SOHBETLER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isActive = index == _activeConversationIndex;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green[50] : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: isActive ? Colors.green[800] : Colors.grey[600]),
                        title: Text(
                          conv.title,
                          style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.green[900] : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isActive ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteConversation(index),
                        ) : null,
                        onTap: () {
                          _switchConversation(index);
                          if (isMobile) Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, isMobile ? 24 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _handleSendMessage(),
              decoration: InputDecoration(
                hintText: "Sera asistanına sor...",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _handleSendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
