import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/ai_service.dart';

// ─── Veri Modelleri ──────────────────────────────────────────────────────────

class Conversation {
  final String id;
  String title;
  final List<Map<String, String>> messages;

  Conversation({required this.id, required this.title, required this.messages});
}

// ─── Sayfa ───────────────────────────────────────────────────────────────────

class AIChatAnalysisPage extends StatefulWidget {
  const AIChatAnalysisPage({super.key});

  @override
  State<AIChatAnalysisPage> createState() => _AIChatAnalysisPageState();
}

class _AIChatAnalysisPageState extends State<AIChatAnalysisPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ─── Sohbet Listesi ──────────────────────────────────────────────────────
  final List<Conversation> _conversations = [];
  int _activeConversationIndex = 0;

  // ─── Firebase Stream Abonelikleri ─────────────────────────────────────────
  StreamSubscription? _sensorSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _controlsSub;

  // ─── Canlı Veri (Stream'den güncellenir) ──────────────────────────────────
  Map _latestSensorData   = {};
  Map _latestSettingsData = {};
  Map _latestControlsData = {};

  // ─── Aksiyon Geri Bildirimi (Snackbar) ────────────────────────────────────
  String? _lastActionMsg;

  @override
  void initState() {
    super.initState();
    _createNewConversation();
    _startFirebaseStreams();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _settingsSub?.cancel();
    _controlsSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Firebase Dinleyicileri ───────────────────────────────────────────────

  void _startFirebaseStreams() {
    // Sensörler
    _sensorSub = FirebaseDatabase.instance
        .ref('Greenhouse/Sensors')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() => _latestSensorData = event.snapshot.value as Map);
      }
    });

    // Ayarlar (bitki listesi, auto_mode vb.)
    _settingsSub = FirebaseDatabase.instance
        .ref('Greenhouse/Settings')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() => _latestSettingsData = event.snapshot.value as Map);
      }
    });

    // Kontroller (fan, pump, light, auto_mode)
    _controlsSub = FirebaseDatabase.instance
        .ref('Greenhouse/Controls')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() => _latestControlsData = event.snapshot.value as Map);
      }
    });
  }

  // ─── Aksiyon Ayrıştırıcı ─────────────────────────────────────────────────

  /// AI cevabındaki [ACTION:DEVICE:STATE] kodlarını yakalar, Firebase'e yazar.
  void _executeActions(String response) {
    final actionRegex = RegExp(r'\[ACTION:(\w+):(\w+)\]');
    final matches = actionRegex.allMatches(response.toUpperCase());

    if (matches.isEmpty) return;

    final ref = FirebaseDatabase.instance.ref('Greenhouse/Controls');
    final Map<String, dynamic> updates = {};
    final List<String> actionLabels = [];

    for (final match in matches) {
      final device = match.group(1)?.toLowerCase(); // fan, pump, light
      final state  = match.group(2)?.toUpperCase(); // ON, OFF

      if (device == null || state == null) continue;

      final int value = (state == 'ON') ? 1 : 0;
      updates[device] = value;

      final String deviceLabel = switch (device) {
        'fan'   => 'Fan',
        'pump'  => 'Pompa',
        'light' => 'Işık/Sisleme',
        _       => device,
      };
      actionLabels.add('$deviceLabel ${state == "ON" ? "AÇILDI ✅" : "KAPATILDI 🔴"}');
    }

    if (updates.isNotEmpty) {
      ref.update(updates).then((_) {
        debugPrint('[ACTION] Firebase güncellendi: $updates');
        if (mounted) {
          setState(() => _lastActionMsg = actionLabels.join(' • '));
          _showActionSnackbar(actionLabels.join(' • '));
        }
      }).catchError((e) {
        debugPrint('[ACTION] Firebase yazma hatası: $e');
      });
    }
  }

  void _showActionSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚡ Aksiyon Alındı: $message',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Sohbet Yönetimi ─────────────────────────────────────────────────────

  void _createNewConversation() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newConv = Conversation(
      id: newId,
      title: 'Sohbet ${_conversations.length + 1}',
      messages: [
        {
          'role': 'ai',
          'text': 'Merhaba! Ben Sera Asistanınız. 🌿\nBitkileriniz hakkında ne bilmek istersiniz?',
        }
      ],
    );
    setState(() {
      _conversations.add(newConv);
      _activeConversationIndex = _conversations.length - 1;
    });
  }

  void _deleteConversation(int index) {
    if (_conversations.length == 1) {
      setState(() => _conversations.clear());
      _createNewConversation();
      return;
    }
    setState(() {
      _conversations.removeAt(index);
      if (_activeConversationIndex >= _conversations.length) {
        _activeConversationIndex = _conversations.length - 1;
      }
    });
  }

  void _switchConversation(int index) => setState(() => _activeConversationIndex = index);

  // ─── Mesaj Gönderme ───────────────────────────────────────────────────────

  Future<void> _handleSendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;
    if (_conversations.isEmpty) return;

    final String userMsg = _controller.text.trim();
    final activeConv = _conversations[_activeConversationIndex];

    // Sohbet başlığını ilk kullanıcı mesajına göre güncelle
    if (activeConv.messages.length == 1) {
      activeConv.title = userMsg.length > 30 ? '${userMsg.substring(0, 30)}…' : userMsg;
    }

    setState(() {
      activeConv.messages.add({'role': 'user', 'text': userMsg});
      _isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      // AI'ya tam bağlam gönder (sensör + ayarlar + kontroller)
      String rawResponse = await AIService.getChatResponse(
        message:      userMsg,
        sensorData:   _latestSensorData,
        settingsData: _latestSettingsData,
        controlsData: _latestControlsData,
      );

      // 1. Gizli aksiyon kodlarını yakala ve Firebase'e uygula
      _executeActions(rawResponse);

      // 2. Kullanıcıya [ACTION:...] kodlarını gösterme — temizle
      final String cleanResponse = rawResponse
          .replaceAll(RegExp(r'\[ACTION:[^\]]*\]', caseSensitive: false), '')
          .trim();

      setState(() {
        activeConv.messages.add({'role': 'ai', 'text': cleanResponse});
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('_handleSendMessage HATA: $e');
      setState(() {
        activeConv.messages.add({
          'role': 'ai',
          'text': 'Sistem Hatası: Lütfen bağlantınızı kontrol edin.',
        });
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeConv = _conversations.isNotEmpty
        ? _conversations[_activeConversationIndex]
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 700;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '🤖 AI Sera Danışmanı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            leading: isMobile
                ? Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.history_rounded),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  )
                : null,
            // Sağ üstte mod göstergesi
            actions: [
              if (_latestControlsData.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildModeBadge(),
                ),
              if (!isMobile)
                TextButton.icon(
                  onPressed: _createNewConversation,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Sohbet'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green[800]),
                ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: isMobile ? _buildSidebar(isMobile: true) : null,
          body: Row(
            children: [
              // Sol panel — sadece web'de sabit
              if (!isMobile) _buildSidebar(isMobile: false),

              // Ana sohbet alanı
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: activeConv == null
                      ? const Center(child: Text('Yeni bir sohbet başlatın'))
                      : Column(
                          children: [
                            // Mesaj listesi
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                itemCount: activeConv.messages.length,
                                itemBuilder: (context, index) {
                                  final msg = activeConv.messages[index];
                                  final bool isUser = msg['role'] == 'user';
                                  return _buildMessageBubble(
                                      msg['text']!, isUser, constraints, isMobile);
                                },
                              ),
                            ),

                            // Yükleniyor göstergesi
                            if (_isLoading)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    backgroundColor: Colors.grey[100],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green[400]!),
                                  ),
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

  // ─── Widget: Mod Rozeti ───────────────────────────────────────────────────

  Widget _buildModeBadge() {
    final int autoMode = ((_latestControlsData['auto_mode'] ?? 0) == true ||
            _latestControlsData['auto_mode'] == 1)
        ? 1
        : 0;
    final bool isAuto = autoMode == 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isAuto ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAuto ? Colors.green[300]! : Colors.orange[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.auto_awesome_rounded : Icons.touch_app_rounded,
            size: 14,
            color: isAuto ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 4),
          Text(
            isAuto ? 'Otomasyon' : 'Manuel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isAuto ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget: Mesaj Balonu ─────────────────────────────────────────────────

  Widget _buildMessageBubble(
      String text, bool isUser, BoxConstraints constraints, bool isMobile) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: isMobile ? constraints.maxWidth * 0.82 : 620,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.green[700] : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            if (isUser)
              BoxShadow(
                color: Colors.green.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  // ─── Widget: Sidebar ──────────────────────────────────────────────────────

  Widget _buildSidebar({required bool isMobile}) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: isMobile ? 16 : 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          border: isMobile
              ? null
              : Border(right: BorderSide(color: Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Sohbet Geçmişi',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _createNewConversation,
                        icon: const Icon(Icons.add_comment_outlined,
                            color: Colors.green),
                      ),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'SOHBETLER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final bool isActive = index == _activeConversationIndex;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green[50] : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: isActive ? Colors.green[800] : Colors.grey[600],
                        ),
                        title: Text(
                          conv.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color:
                                isActive ? Colors.green[900] : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isActive
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Colors.redAccent),
                                onPressed: () => _deleteConversation(index),
                              )
                            : null,
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

  // ─── Widget: Giriş Alanı ─────────────────────────────────────────────────

  Widget _buildInputArea(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, isMobile ? 24 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _handleSendMessage(),
              decoration: InputDecoration(
                hintText: 'Sera asistanına sor…',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey[300] : Colors.green[700],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!_isLoading)
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: _isLoading ? null : _handleSendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
