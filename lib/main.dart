import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

void main() {
  runApp(const ArabChatApp());
}

class ArabChatApp extends StatelessWidget {
  const ArabChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ArabChat',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7DD3FC),
        scaffoldBackgroundColor: const Color(0xFF0A0A0B),
        fontFamily: 'Roboto',
      ),
      home: const ArabChatHome(),
    );
  }
}

class ArabChatHome extends StatefulWidget {
  const ArabChatHome({super.key});

  @override
  State<ArabChatHome> createState() => _ArabChatHomeState();
}

enum NameStatus { idle, checking, ok, taken, invalid }

class Message {
  final String id;
  final String user;
  final String text;
  final DateTime ts;
  const Message({required this.id, required this.user, required this.text, required this.ts});
}

class _ArabChatHomeState extends State<ArabChatHome> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _listCtrl = ScrollController();

  NameStatus _nameStatus = NameStatus.idle;
  String _nameMsg = '';
  String get _username => _usernameCtrl.text;

  bool _emojiOpen = false;
  int _online = 3; // placeholder until sockets are wired in client
  Timer? _debounce;

  final List<Message> _messages = [
    Message(
      id: 'sys',
      user: 'نظام',
      text: 'أهلًا بيك بعرب شات ✨ اكتب اسم مستخدم وابدأ الدردشة!',
      ts: DateTime.now(),
    ),
  ];

  static const List<String> popularEmojis = [
    '😀','😂','🤣','😊','😍','😘','😎','🤩','😉','😇',
    '😅','🙃','🥲','😭','😤','🤔','🤗','🙌','👏','👍',
    '🔥','💯','✨','💫','🌟','💔','❤️','🧡','💛','💚',
    '💙','💜','🤍','🤎','🖤','🤝','🙏','🎉','🎊','🥳',
    '☕','🍕','🍔','🍟','🍿','🍫','🍩','🍪','🍰','🧊',
  ];

  bool get canChat => _nameStatus == NameStatus.ok;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _usernameCtrl.removeListener(_onNameChanged);
    _usernameCtrl.dispose();
    _inputCtrl.dispose();
    _listCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    final val = _usernameCtrl.text;
    _debounce?.cancel();
    if (val.isEmpty) {
      setState(() { _nameStatus = NameStatus.idle; _nameMsg = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _checkUsername(val));
  }

  bool _isValidName(String n) {
    if (n.isEmpty) return false;
    if (n.length < 3) return false;
    if (n.trim() != n) return false;
    if (n.contains(RegExp(r"\s"))) return false;
    final reg = RegExp(r'^[\p{L}0-9_.-]+$', unicode: true);
    return reg.hasMatch(n);
  }

  Future<void> _checkUsername(String n) async {
    if (!_isValidName(n)) {
      setState(() {
        _nameStatus = NameStatus.invalid;
        _nameMsg = 'الاسم يجب يكون 3 أحرف على الأقل وبدون مسافة';
      });
      return;
    }

    setState(() { _nameStatus = NameStatus.checking; _nameMsg = ''; });

    try {
      final uri = Uri.parse('$apiBaseUrl/api/check-username').replace(queryParameters: {'u': n});
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final available = data['available'] == true;
        setState(() {
          _nameStatus = available ? NameStatus.ok : NameStatus.taken;
          _nameMsg = (data['message'] as String?) ?? (available ? 'الاسم متاح' : 'الاسم غير متاح');
        });
      } else {
        setState(() { _nameStatus = NameStatus.taken; _nameMsg = 'تعذر التحقق مؤقتًا'; });
      }
    } catch (_) {
      setState(() { _nameStatus = NameStatus.taken; _nameMsg = 'تعذر الاتصال بالسيرفر'; });
    }
  }

  void _sendMessage() {
    final txt = _inputCtrl.text.trim();
    if (txt.isEmpty || !canChat) return;
    final msg = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      user: _username,
      text: txt,
      ts: DateTime.now(),
    );
    setState(() {
      _messages.add(msg);
      _inputCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listCtrl.hasClients) {
        _listCtrl.animateTo(
          _listCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addEmoji(String e) {
    final cursor = _inputCtrl.selection.baseOffset;
    final text = _inputCtrl.text;
    if (cursor >= 0) {
      final newText = text.replaceRange(cursor, cursor, e);
      _inputCtrl.text = newText;
      _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: cursor + e.length));
    } else {
      _inputCtrl.text += e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, -0.8),
              radius: 1.2,
              colors: [Color(0x1AFFFFFF), Colors.transparent],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        const _GlossOverlay(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, bc) {
                final isWide = bc.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: isWide ? Row(
                        children: [
                          Expanded(flex: 4, child: _glassCard(child: _Sidebar(
                            usernameCtrl: _usernameCtrl,
                            nameStatus: _nameStatus,
                            nameMsg: _nameMsg,
                            online: _online,
                          ))),
                          const SizedBox(width: 12),
                          Expanded(flex: 7, child: _glassCard(child: _ChatArea(
                            messages: _messages,
                            listCtrl: _listCtrl,
                            inputCtrl: _inputCtrl,
                            emojiOpen: _emojiOpen,
                            canChat: canChat,
                            onToggleEmoji: () => setState(() => _emojiOpen = !_emojiOpen),
                            onSend: _sendMessage,
                            onAddEmoji: _addEmoji,
                          ))),
                        ],
                      ) : Column(
                        children: [
                          _glassCard(child: _Sidebar(
                            usernameCtrl: _usernameCtrl,
                            nameStatus: _nameStatus,
                            nameMsg: _nameMsg,
                            online: _online,
                          )),
                          const SizedBox(height: 12),
                          Expanded(child: _glassCard(child: _ChatArea(
                            messages: _messages,
                            listCtrl: _listCtrl,
                            inputCtrl: _inputCtrl,
                            emojiOpen: _emojiOpen,
                            canChat: canChat,
                            onToggleEmoji: () => setState(() => _emojiOpen = !_emojiOpen),
                            onSend: _sendMessage,
                            onAddEmoji: _addEmoji,
                          ))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 20)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final TextEditingController usernameCtrl;
  final NameStatus nameStatus;
  final String nameMsg;
  final int online;

  const _Sidebar({
    required this.usernameCtrl,
    required this.nameStatus,
    required this.nameMsg,
    required this.online,
  });

  Color _statusColor(BuildContext ctx) {
    switch (nameStatus) {
      case NameStatus.ok:
        return Colors.greenAccent.shade200;
      case NameStatus.taken:
        return Colors.redAccent.shade200;
      case NameStatus.invalid:
        return Colors.amberAccent.shade200;
      case NameStatus.checking:
        return Theme.of(ctx).colorScheme.secondary;
      case NameStatus.idle:
        return Colors.white70;
    }
  }

  IconData _statusIcon() {
    switch (nameStatus) {
      case NameStatus.ok:
        return Icons.check_rounded;
      case NameStatus.taken:
      case NameStatus.invalid:
        return Icons.close_rounded;
      case NameStatus.checking:
        return Icons.autorenew_rounded;
      case NameStatus.idle:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Arab Chat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            const Opacity(opacity: 0.6, child: Text('بيتا', style: TextStyle(fontSize: 16))),
          ],
        ),
        const SizedBox(height: 16),
        const Opacity(opacity: 0.8, child: Text('اسم المستخدم', style: TextStyle(fontSize: 13))),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: usernameCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'اكتب اسمك بدون مسافات',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Center(child: Icon(_statusIcon(), color: _statusColor(context))),
            )
          ],
        ),
        if (nameMsg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              nameMsg,
              style: TextStyle(fontSize: 13, color: _statusColor(context)),
              textDirection: TextDirection.rtl,
            ),
          ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.people_alt_outlined),
              const SizedBox(width: 8),
              const Text('متصلين الآن'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x2622C55E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4D22C55E)),
                ),
                child: Text('$online', style: const TextStyle(color: Color(0xFF86EFAC))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Opacity(
          opacity: 0.8,
          child: Text('• التصميم زجاجي لامع مع ظل ناعم.\n• اكتب اسم مستخدم متاح حتى تشتغل الدردشة.\n• لوحة إيموجي مدمجة – كبس وأدرج بسرعة ✨',
              textDirection: TextDirection.rtl),
        ),
      ],
    );
  }
}

class _ChatArea extends StatelessWidget {
  final List<Message> messages;
  final ScrollController listCtrl;
  final TextEditingController inputCtrl;
  final bool emojiOpen;
  final bool canChat;
  final VoidCallback onToggleEmoji;
  final VoidCallback onSend;
  final void Function(String) onAddEmoji;

  const _ChatArea({
    required this.messages,
    required this.listCtrl,
    required this.inputCtrl,
    required this.emojiOpen,
    required this.canChat,
    required this.onToggleEmoji,
    required this.onSend,
    required this.onAddEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: listCtrl,
            padding: const EdgeInsets.only(right: 6, bottom: 8),
            itemCount: messages.length,
            itemBuilder: (ctx, i) {
              final m = messages[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x26000000), blurRadius: 20, offset: Offset(0, 10)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Opacity(
                          opacity: 0.7,
                          child: Text(
                            '${m.user} • ${TimeOfDay.fromDateTime(m.ts).format(context)}',
                            style: const TextStyle(fontSize: 12),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(m.text, textDirection: TextDirection.rtl),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _roundBtn(
                    icon: Icons.emoji_emotions_outlined,
                    onTap: onToggleEmoji,
                    tooltip: 'إيموجي',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: inputCtrl,
                      minLines: 1,
                      maxLines: 5,
                      enabled: canChat,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: canChat ? 'اكتب رسالتك هنا...' : 'اختر اسم مستخدم متاح أولًا',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roundBtn(icon: Icons.send_rounded, onTap: onSend, tooltip: 'إرسال'),
                ],
              ),
              if (emojiOpen) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  padding: const EdgeInsets.all(8),
                  height: 200,
                  child: GridView.count(
                    crossAxisCount: 10,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: _buildEmojiButtons(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEmojiButtons() {
    return _ArabChatHomeState.popularEmojis
        .map((e) => InkWell(
              onTap: () => onAddEmoji(e),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            ))
        .toList();
  }

  Widget _roundBtn({required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _GlossOverlay extends StatelessWidget {
  const _GlossOverlay();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x1AFFFFFF), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
