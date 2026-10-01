import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/chat_provider.dart';
import '../services/auth_service.dart';
import '../models/chat_message.dart';
import 'events_screen.dart';
import 'auth_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getUserSession();
    if (mounted && user != null) {
      setState(() {
        _userData = user;
      });
    }
  }

  String get _userInitials {
    final name = _userData?['full_name'] as String? ?? 'Chopra Srihari';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'CS';
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    await AuthService.clearUserSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open link: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF000000), // Pitch Black ChatGPT Style
      drawer: _buildChatGPTDrawer(chatProvider),
      appBar: _buildChatGPTAppBar(chatProvider),
      body: Column(
        children: [
          // Main Content: Welcome Screen or Message List
          Expanded(
            child: chatProvider.messages.isEmpty
                ? _buildChatGPTGreetingScreen(chatProvider)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      return _buildChatGPTBubble(message);
                    },
                  ),
          ),

          // Loading Indicator when AI is thinking
          if (chatProvider.isLoading) _buildAIThinkingIndicator(),

          // ChatGPT Style Bottom Input Bar
          _buildChatGPTInputBar(chatProvider),
        ],
      ),
    );
  }

  /* ── 1. ChatGPT Top App Bar with Gentle Touch Padding ── */
  PreferredSizeWidget _buildChatGPTAppBar(ChatProvider provider) {
    return AppBar(
      backgroundColor: const Color(0xFF000000),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          tooltip: 'Open Menu',
          onPressed: () {
            HapticFeedback.lightImpact();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      title: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showModelSelectorModal(context);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DIET AI Assistant',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 18),
            ],
          ),
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
            ),
            tooltip: 'New Chat',
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.startNewChat();
            },
          ),
        ),
      ],
    );
  }

  /* ── 2. ChatGPT Side Navigation Drawer ── */
  Widget _buildChatGPTDrawer(ChatProvider provider) {
    return Drawer(
      backgroundColor: const Color(0xFF000000),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'DIET AI Assistant',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF1E1E1E), height: 1),

            // Middle Scrollable: Features & Recent Chats History
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  // Quick Feature Shortcuts Section
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8, top: 4),
                    child: Text(
                      'EXPLORE FEATURES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  _buildDrawerFeatureItem(
                    icon: Icons.event_rounded,
                    color: const Color(0xFF38BDF8),
                    title: 'Campus Events & Posters',
                    subtitle: 'Workshops, hackathons & fests',
                    onTap: () {
                      Navigator.of(context).pop();
                      _openEventsModal(context);
                    },
                  ),
                  _buildDrawerFeatureItem(
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF8B5CF6),
                    title: 'Syllabus & Lecture Notes',
                    subtitle: 'Subject codes & PDF materials',
                    onTap: () {
                      Navigator.of(context).pop();
                      _controller.text = 'Show syllabus for CS302 Database Systems';
                      _sendMessage(provider);
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF1E1E1E), height: 1),
                  const SizedBox(height: 12),

                  // Recent Chat History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'RECENT CHATS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (provider.history.isNotEmpty)
                        TextButton(
                          onPressed: () => provider.clearChat(),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Clear', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (provider.history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No recent conversations yet.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                      ),
                    )
                  else
                    ...provider.history.map((session) {
                      final isSelected = session.id == provider.activeSessionId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF171717) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF64748B)),
                            onPressed: () => provider.deleteSession(session.id),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            provider.loadSession(session);
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),

            const Divider(color: Color(0xFF1E1E1E), height: 1),

            // Bottom Profile Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFF000000),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userData?['full_name'] ?? 'Chopra Srihari',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_userData?['roll_number'] ?? "23U41A4216"} • ${_userData?['department'] ?? "CSM (AI & ML)"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // User Avatar on Right
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _userInitials,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Logout Button
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Logout',
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF475569)),
            ],
          ),
        ),
      ),
    );
  }

  /* ── 3. ChatGPT Greeting Screen with Gentle Shortcut Chips ── */
  Widget _buildChatGPTGreetingScreen(ChatProvider provider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),

            // Shortcut Actions at Bottom-Left with Gentle Touch Target
            _buildChatGPTShortcutItem(
              icon: Icons.image_outlined,
              label: 'Explore Campus Events & Posters',
              onTap: () => _openEventsModal(context),
            ),
            const SizedBox(height: 12),
            _buildChatGPTShortcutItem(
              icon: Icons.edit_note_rounded,
              label: 'Syllabus & Course Lecture Notes',
              onTap: () {
                _controller.text = 'Show syllabus for CS302 Database Systems';
                _sendMessage(provider);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChatGPTShortcutItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF10B981), size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── 4. ChatGPT Style Message Bubble ── */
  Widget _buildChatGPTBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10, top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 16),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF262626) : const Color(0xFF121212),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isUser ? Colors.transparent : Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message.content,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Colors.white,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: message.content,
                      onTapLink: (text, href, title) {
                        if (href != null) _launchURL(href);
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14.5, color: Color(0xFFECECF1), height: 1.55),
                        h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        code: const TextStyle(
                          backgroundColor: Color(0xFF000000),
                          color: Color(0xFF10B981),
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                      ),
                    ),

                  // Image Poster Banner if returned by RAG
                  if (message.imageUrl != null && message.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () => _showFullImage(context, message.imageUrl!),
                        child: Stack(
                          children: [
                            _buildEventImage(message.imageUrl!, height: 180),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.zoom_in, size: 12, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text('Tap to zoom', style: TextStyle(fontSize: 10, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Citations / Sources Chips
                  if (!isUser && message.citations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.citations.map((source) {
                        return Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.68,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined, size: 11, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  source,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventImage(String imageUrl, {double height = 180}) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return Container(height: height, color: const Color(0xFF000000));
      }
    } else {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
      );
    }
  }

  void _showFullImage(BuildContext ctx, String imageUrl) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildEventImage(imageUrl, height: MediaQuery.of(ctx).size.height * 0.75),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── 5. AI Thinking Indicator ── */
  Widget _buildAIThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'DIET AI is thinking…',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ── 6. ChatGPT Style Floating Input Bar ("Ask DIET AI...") ── */
  Widget _buildChatGPTInputBar(ChatProvider provider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF212121), // ChatGPT Dark Input Bar Color
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    // Plus Attachment Icon
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _openEventsModal(context);
                      },
                    ),

                    // Text Field with "Ask DIET AI..."
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 15, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Ask DIET AI...',
                          hintStyle: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(provider),
                      ),
                    ),

                    // Mic Icon
                    IconButton(
                      icon: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Voice input active'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),

                    // Green ChatGPT Circular Voice Waveform / Send Button
                    GestureDetector(
                      onTap: () => _sendMessage(provider),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // ChatGPT Green #10B981
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ChatProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty || provider.isLoading) return;
    HapticFeedback.mediumImpact();
    _controller.clear();
    provider.sendChatMessage(text);
    _scrollToBottom();
  }

  void _openEventsModal(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => const EventsScreen(),
      ),
    );
  }

  /* Model Selector Modal with SafeArea (Fixes screenshot 3 cutoff!) */
  void _showModelSelectorModal(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF171717),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              const Text('Select AI Engine', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 20),
                  ),
                  title: const Text('DIET AI 4.0 Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('CRAG Engine + Gemini 3.6 Multimodal', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
