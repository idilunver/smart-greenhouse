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

    return Scaffold(
      appBar: AppBar(
        title: const Text("🤖 AI Danışmanlık", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Row(
        children: [
          // --- SOL PANEL: Sohbet Listesi ---
          SizedBox(
            width: 220,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Yeni Sohbet butonu
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ElevatedButton.icon(
                      onPressed: _createNewConversation,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Yeni Sohbet", style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                    child: Text("SOHBETLER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ),
                  // Sohbet listesi
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        final isActive = index == _activeConversationIndex;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green[50] : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isActive ? Border.all(color: Colors.green[200]!) : null,
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            leading: Icon(Icons.chat_bubble_outline, size: 16, color: isActive ? Colors.green[700] : Colors.grey),
                            title: Text(
                              conv.title,
                              style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.green[800] : Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, size: 16, color: Colors.grey[400]),
                              tooltip: "Sohbeti Sil",
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _deleteConversation(index),
                            ),
                            onTap: () => _switchConversation(index),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- SAĞ PANEL: Aktif Sohbet ---
          Expanded(
            child: activeConv == null
                ? const Center(child: Text("Yeni bir sohbet başlatın"))
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: activeConv.messages.length,
                          itemBuilder: (context, index) {
                            bool isUser = activeConv.messages[index]['role'] == 'user';
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.green[600] : Colors.grey[200],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                                    bottomRight: Radius.circular(isUser ? 0 : 16),
                                  ),
                                ),
                                child: Text(
                                  activeConv.messages[index]['text']!,
                                  style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 13),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 5,
                                onSubmitted: (_) => _handleSendMessage(),
                                decoration: InputDecoration(
                                  hintText: "Soru sor...",
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              backgroundColor: Colors.green,
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                                onPressed: _handleSendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
