import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/ai_service.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class Conversation {
  final String id;
  String title;
  final List<Map<String, String>> messages;

  Conversation({required this.id, required this.title, required this.messages});
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AIChatAnalysisPage extends StatefulWidget {
  const AIChatAnalysisPage({super.key});

  @override
  State<AIChatAnalysisPage> createState() => _AIChatAnalysisPageState();
}

class _AIChatAnalysisPageState extends State<AIChatAnalysisPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ─── Conversation List ────────────────────────────────────────────────────
  final List<Conversation> _conversations = [];
  int _activeConversationIndex = 0;

  // ─── Firebase Stream Subscriptions ───────────────────────────────────────
  StreamSubscription? _sensorSub;
  StreamSubscription? _settingsSub;
  StreamSubscription? _controlsSub;

  // ─── Live Data (updated from stream) ─────────────────────────────────────
  Map _latestSensorData   = {};
  Map _latestSettingsData = {};
  Map _latestControlsData = {};

  // ─── Action Feedback (Snackbar) ───────────────────────────────────────────
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

  // ─── Firebase Listeners ───────────────────────────────────────────────────

  void _startFirebaseStreams() {
    // Sensors
    _sensorSub = FirebaseDatabase.instance
        .ref('Greenhouse/Sensors')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() => _latestSensorData = event.snapshot.value as Map);
      }
    });

    // Settings (plant list, auto_mode, etc.)
    _settingsSub = FirebaseDatabase.instance
        .ref('Greenhouse/Settings')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() => _latestSettingsData = event.snapshot.value as Map);
      }
    });

    // Controls (fan, pump, light, auto_mode)
    _controlsSub = FirebaseDatabase.instance
        .ref('Greenhouse/Controls')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        setState(() => _latestControlsData = event.snapshot.value as Map);
      }
    });
  }

  // ─── Action Parser ────────────────────────────────────────────────────────

  /// Captures [ACTION:DEVICE:STATE] codes from the AI response and writes them to Firebase.
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
        'pump'  => 'Pump',
        'light' => 'Light/Misting',
        _       => device,
      };
      actionLabels.add('$deviceLabel ${state == "ON" ? "ACTIVATED ✅" : "DEACTIVATED 🔴"}');
    }

    if (updates.isNotEmpty) {
      ref.update(updates).then((_) {
        debugPrint('[ACTION] Firebase updated: $updates');
        if (mounted) {
          setState(() => _lastActionMsg = actionLabels.join(' • '));
          _showActionSnackbar(actionLabels.join(' • '));
        }
      }).catchError((e) {
        debugPrint('[ACTION] Firebase write error: $e');
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
                '⚡ Action Executed: $message',
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

  // ─── Conversation Management ──────────────────────────────────────────────

  void _createNewConversation() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newConv = Conversation(
      id: newId,
      title: 'Conversation ${_conversations.length + 1}',
      messages: [
        {
          'role': 'ai',
          'text': 'Hello! I am your Greenhouse Assistant. 🌿\nWhat would you like to know about your plants?',
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

  // ─── Message Sending ──────────────────────────────────────────────────────

  Future<void> _handleSendMessage() async {
    if (_controller.text.trim().isEmpty || _isLoading) return;
    if (_conversations.isEmpty) return;

    final String userMsg = _controller.text.trim();
    final activeConv = _conversations[_activeConversationIndex];

    // Update conversation title based on the first user message
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
      // Send full context to AI (sensors + settings + controls)
      String rawResponse = await AIService.getChatResponse(
        message:      userMsg,
        sensorData:   _latestSensorData,
        settingsData: _latestSettingsData,
        controlsData: _latestControlsData,
      );

      // 1. Capture hidden action codes and apply them to Firebase
      _executeActions(rawResponse);

      // 2. Strip [ACTION:...] codes before displaying response to the user
      final String cleanResponse = rawResponse
          .replaceAll(RegExp(r'\[ACTION:[^\]]*\]', caseSensitive: false), '')
          .trim();

      setState(() {
        activeConv.messages.add({'role': 'ai', 'text': cleanResponse});
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('_handleSendMessage ERROR: $e');
      setState(() {
        activeConv.messages.add({
          'role': 'ai',
          'text': 'System Error: Please check your connection.',
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
              '🤖 AI Greenhouse Advisor',
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
            // Mode indicator in the top-right corner
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
                  label: const Text('New Chat'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green[800]),
                ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: isMobile ? _buildSidebar(isMobile: true) : null,
          body: Row(
            children: [
              // Left panel — fixed on web only
              if (!isMobile) _buildSidebar(isMobile: false),

              // Main chat area
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF8FAFC), Colors.white],
                    ),
                  ),
                  child: activeConv == null
                      ? const Center(child: Text('Start a new conversation'))
                      : Column(
                          children: [
                            _buildSensorWarningBanner(),
                            // Message list
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

                            // Loading indicator
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

  // ─── Widget: Mode Badge ───────────────────────────────────────────────────

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
            isAuto ? 'Automation' : 'Manual',
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

  // ─── Widget: Message Bubble ───────────────────────────────────────────────

  Widget _buildMessageBubble(
      String text, bool isUser, BoxConstraints constraints, bool isMobile) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: isMobile ? constraints.maxWidth * 0.85 : 650,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 22),
          ),
          border: isUser ? null : Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'AI ASSISTANT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.6,
                fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widget: Sensor Warning Banner ────────────────────────────────────────

  Widget _buildSensorWarningBanner() {
    final double temp = double.tryParse(_latestSensorData['temp_inner']?.toString() ?? '0') ?? 0;
    final double hum = double.tryParse(_latestSensorData['humidity_inner']?.toString() ?? '0') ?? 0;

    if (temp != 0 && hum != 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_off_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sensor Connection Issue: Internal temperature and humidity data cannot be retrieved. Please check the hardware connections and the I2C bus (0x76).',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Try checking SDA/SCL pins on your ESP32.')),
              );
            },
            child: const Text('HELP', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
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
                        'Chat History',
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
                  'CONVERSATIONS',
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

  // ─── Widget: Input Area ───────────────────────────────────────────────────

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
                hintText: 'Ask the greenhouse assistant…',
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