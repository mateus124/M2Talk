import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const M2TalkApp());
}

const String apiHost = String.fromEnvironment(
  'API_HOST',
  defaultValue: '10.0.2.2:8000',
);

const _bg = Color(0xFF050917);
const _panel = Color(0xFF080D1D);
const _field = Color(0xFF121A2D);
const _border = Color(0xFF26314C);
const _muted = Color(0xFF91A0BE);
const _accent = Color(0xFF2F83F7);
const _online = Color(0xFF0BDF87);

class M2TalkApp extends StatelessWidget {
  const M2TalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'M2Talk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
      ),
      home: const AppGate(),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  Session? _session;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('userId');
    final name = prefs.getString('name');
    setState(() {
      _session = token != null && userId != null && name != null
          ? Session(token: token, userId: userId, name: name)
          : null;
      _loading = false;
    });
  }

  Future<void> _setSession(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', session.token);
    await prefs.setInt('userId', session.userId);
    await prefs.setString('name', session.name);
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _session == null
        ? AuthScreen(onAuthenticated: _setSession)
        : ChatShell(session: _session!, onLogout: _logout);
  }
}

class Session {
  const Session({
    required this.token,
    required this.userId,
    required this.name,
  });

  final String token;
  final int userId;
  final String name;
}

class ApiClient {
  ApiClient({required this.session});

  final Session? session;
  static final _base = Uri.parse('http://$apiHost');
  static final _wsBase = Uri.parse('ws://$apiHost');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (session != null) 'Authorization': 'Bearer ${session!.token}',
  };

  static Future<Session> login(String email, String password) async {
    final res = await http.post(
      _base.replace(path: '/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'senha': password}),
    );
    final json = _decode(res);
    if (res.statusCode != 200) throw ApiException.fromJson(json);
    return Session(
      token: json['access_token'] as String,
      userId: json['user_id'] as int,
      name: json['nome'] as String,
    );
  }

  static Future<void> register(
    String name,
    String email,
    String password,
  ) async {
    final res = await http.post(
      _base.replace(path: '/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nome': name, 'email': email, 'senha': password}),
    );
    if (res.statusCode != 201) throw ApiException.fromJson(_decode(res));
  }

  Future<List<GroupInfo>> groups() async {
    final res = await http.get(
      _base.replace(path: '/api/groups'),
      headers: _headers,
    );
    final json = _decode(res);
    if (res.statusCode != 200) throw ApiException.fromJson(json);
    final groups = (json['groups'] as List<dynamic>? ?? [])
        .map((item) => GroupInfo.fromJson(item as Map<String, dynamic>))
        .toList();
    return groups;
  }

  Future<List<ChatMessage>> history() async {
    final res = await http.get(
      _base.replace(path: '/api/chat/history'),
      headers: _headers,
    );
    final json = _decode(res);
    if (res.statusCode != 200) throw ApiException.fromJson(json);
    return (json as List<dynamic>)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createGroup(String name) async {
    final res = await http.post(
      _base.replace(path: '/api/groups'),
      headers: _headers,
      body: jsonEncode({'nome': name}),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw ApiException.fromJson(_decode(res));
    }
  }

  Future<void> sendGroupMessage(String groupName, String message) async {
    final res = await http.post(
      _base.replace(path: '/api/groups/$groupName/message'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    );
    if (res.statusCode != 200) throw ApiException.fromJson(_decode(res));
  }

  Future<void> joinGroup(String groupName) async {
    await http.post(
      _base.replace(path: '/api/groups/$groupName/join'),
      headers: _headers,
    );
  }

  static dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<WebSocketChannel?> connectWebSocket() async {
    if (session == null) return null;
    final token = Uri.encodeComponent(session!.token);
    final candidates = [
      '/ws?token=$token',
      '/ws/${session!.token}',
      '/api/ws?token=$token',
      '/api/chat/ws?token=$token',
      '/ws/chat?token=$token',
    ];
    for (final path in candidates) {
      try {
        final socket = await WebSocket.connect(
          _wsBase
              .replace(
                path: path.split('?').first,
                query: path.contains('?') ? path.split('?').last : null,
              )
              .toString(),
        ).timeout(const Duration(seconds: 2));
        return IOWebSocketChannel(socket);
      } catch (_) {}
    }
    return null;
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  factory ApiException.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      final detail = json['detail'];
      if (detail is String) return ApiException(detail);
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return ApiException(first['msg'].toString());
        }
      }
    }
    return ApiException('Nao foi possivel concluir a operacao.');
  }

  @override
  String toString() => message;
}

class GroupInfo {
  const GroupInfo({required this.id, required this.name});

  final int id;
  final String name;

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(id: json['id'] as int? ?? 0, name: json['nome'] as String);
  }
}

class ChatMessage {
  ChatMessage({
    required this.message,
    required this.timestamp,
    required this.groupName,
    required this.senderName,
    required this.senderId,
  });

  final String message;
  final DateTime timestamp;
  final String groupName;
  final String senderName;
  final int? senderId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final sender = from is Map ? from : <String, dynamic>{};
    final group =
        json['group_name'] ??
        json['conversation_name'] ??
        json['conversation_key'] ??
        'Grupo';
    return ChatMessage(
      message: (json['message'] ?? json['content'] ?? json['text'] ?? '')
          .toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      groupName: group.toString(),
      senderName:
          (json['sender_name'] ??
                  json['from_name'] ??
                  sender['nome'] ??
                  sender['name'] ??
                  'Usuario')
              .toString(),
      senderId: json['sender_id'] is int
          ? json['sender_id'] as int
          : sender['id'] is int
          ? sender['id'] as int
          : sender['user_id'] is int
          ? sender['user_id'] as int
          : null,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final ValueChanged<Session> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _register = false;
  var _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_register) {
        await ApiClient.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      }
      final session = await ApiClient.login(_email.text.trim(), _password.text);
      widget.onAuthenticated(session);
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomRight,
            radius: 1.2,
            colors: [Color(0xFF062737), _bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _panel,
                  border: Border.all(color: const Color(0xFF1E2944)),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LogoTitle(),
                    const SizedBox(height: 8),
                    const Text(
                      'Sistema de chat em tempo real',
                      style: TextStyle(color: _muted, fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    SegmentedToggle(
                      activeRight: _register,
                      left: 'Entrar',
                      right: 'Cadastrar',
                      onChanged: (value) => setState(() => _register = value),
                    ),
                    const SizedBox(height: 28),
                    if (_register) ...[
                      AppTextField(controller: _name, hint: 'Nome'),
                      const SizedBox(height: 14),
                    ],
                    AppTextField(controller: _email, hint: 'Email'),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _password,
                      hint: 'Senha',
                      obscure: true,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_register ? 'Criar conta' : 'Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatShell extends StatefulWidget {
  const ChatShell({super.key, required this.session, required this.onLogout});

  final Session session;
  final VoidCallback onLogout;

  @override
  State<ChatShell> createState() => _ChatShellState();
}

class _ChatShellState extends State<ChatShell> {
  late final ApiClient _api;
  WebSocketChannel? _channel;
  var _groups = <GroupInfo>[];
  var _messages = <ChatMessage>[];
  GroupInfo? _selected;
  var _loading = true;
  var _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(session: widget.session);
    _load();
    _connectWs();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.groups(), _api.history()]);
      setState(() {
        _groups = results[0] as List<GroupInfo>;
        _messages = results[1] as List<ChatMessage>;
        _loading = false;
      });
    } catch (error) {
      setState(() => _loading = false);
      _toast(error.toString());
    }
  }

  Future<void> _connectWs() async {
    final channel = await _api.connectWebSocket();
    if (!mounted || channel == null) return;
    _channel = channel;
    setState(() => _wsConnected = true);
    channel.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event.toString());
          if (data is Map<String, dynamic>) {
            final message = ChatMessage.fromJson(data);
            final duplicated = _messages.any(
              (current) =>
                  current.groupName == message.groupName &&
                  current.senderId == message.senderId &&
                  current.message == message.message &&
                  current.timestamp
                          .difference(message.timestamp)
                          .abs()
                          .inSeconds <
                      3,
            );
            if (!duplicated) setState(() => _messages.add(message));
          }
        } catch (_) {}
      },
      onDone: () {
        if (mounted) setState(() => _wsConnected = false);
      },
      onError: (_) {
        if (mounted) setState(() => _wsConnected = false);
      },
    );
  }

  List<ChatMessage> get _selectedMessages {
    final group = _selected?.name;
    if (group == null) return [];
    return _messages.where((m) => m.groupName == group).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> _createGroup() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CreateGroupDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await _api.createGroup(name.trim());
      await _load();
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _send(String text) async {
    final selected = _selected;
    if (selected == null || text.trim().isEmpty) return;
    try {
      await _api.joinGroup(selected.name);
      await _api.sendGroupMessage(selected.name, text.trim());
      setState(() {
        _messages.add(
          ChatMessage(
            message: text.trim(),
            timestamp: DateTime.now(),
            groupName: selected.name,
            senderName: widget.session.name,
            senderId: widget.session.userId,
          ),
        );
      });
    } catch (error) {
      _toast(error.toString());
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selected == null
            ? ConversationList(
                session: widget.session,
                groups: _groups,
                messages: _messages,
                loading: _loading,
                wsConnected: _wsConnected,
                onLogout: widget.onLogout,
                onCreateGroup: _createGroup,
                onSelect: (group) => setState(() => _selected = group),
              )
            : ChatView(
                session: widget.session,
                group: _selected!,
                messages: _selectedMessages,
                onBack: () => setState(() => _selected = null),
                onSend: _send,
              ),
      ),
    );
  }
}

class ConversationList extends StatefulWidget {
  const ConversationList({
    super.key,
    required this.session,
    required this.groups,
    required this.messages,
    required this.loading,
    required this.wsConnected,
    required this.onLogout,
    required this.onCreateGroup,
    required this.onSelect,
  });

  final Session session;
  final List<GroupInfo> groups;
  final List<ChatMessage> messages;
  final bool loading;
  final bool wsConnected;
  final VoidCallback onLogout;
  final VoidCallback onCreateGroup;
  final ValueChanged<GroupInfo> onSelect;

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  final _search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final groups = widget.groups
        .where((g) => g.name.toLowerCase().contains(query))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(
            children: [
              InitialsAvatar(
                text: widget.session.name,
                color: const Color(0xFF8CC62D),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.wsConnected ? _online : _muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.wsConnected ? 'Online' : 'Conectado',
                          style: const TextStyle(color: _online, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sair',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, color: _muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: AppTextField(
            controller: _search,
            hint: 'Buscar conversas...',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : groups.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma conversa encontrada',
                    style: TextStyle(color: _muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  itemCount: groups.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final last =
                        widget.messages
                            .where((m) => m.groupName == group.name)
                            .toList()
                          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                    return ConversationTile(
                      group: group,
                      last: last.isEmpty ? null : last.first,
                      onTap: () => widget.onSelect(group),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF1C2740))),
          ),
          child: OutlinedButton.icon(
            onPressed: widget.onCreateGroup,
            icon: const Icon(Icons.add),
            label: const Text('Novo Grupo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              foregroundColor: const Color(0xFF8BBEFF),
              side: const BorderSide(color: Color(0xFF1E62BC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.session,
    required this.group,
    required this.messages,
    required this.onBack,
    required this.onSend,
  });

  final Session session;
  final GroupInfo group;
  final List<ChatMessage> messages;
  final VoidCallback onBack;
  final ValueChanged<String> onSend;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();

  void _send() {
    final text = _input.text;
    _input.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          decoration: const BoxDecoration(
            color: _panel,
            border: Border(bottom: BorderSide(color: Color(0xFF1C2740))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              InitialsAvatar(
                text: widget.group.name,
                color: avatarColor(widget.group.name),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Grupo',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.messages.isEmpty
              ? const EmptyChat()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final message = widget.messages[index];
                    final mine =
                        message.senderId == widget.session.userId ||
                        message.senderName == widget.session.name;
                    return MessageBubble(message: message, mine: mine);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: _panel,
            border: Border(top: BorderSide(color: Color(0xFF1C2740))),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _input,
                  hint: 'Digite uma mensagem...',
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _send,
                style: IconButton.styleFrom(
                  backgroundColor: _accent,
                  minimumSize: const Size(52, 52),
                ),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? _accent : _field,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                message.senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            Text(message.message, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: mine ? Colors.white70 : _muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.group,
    required this.last,
    required this.onTap,
  });

  final GroupInfo group;
  final ChatMessage? last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            InitialsAvatar(text: group.name, color: avatarColor(group.name)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    last == null
                        ? 'Grupo'
                        : '${last!.senderName}: ${last!.message}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (last != null)
              Text(
                _formatTime(last!.timestamp),
                style: const TextStyle(color: Color(0xFF65779C), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _name = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text('Novo grupo'),
      content: AppTextField(controller: _name, hint: 'Nome do grupo'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_rounded, size: 48, color: Color(0xFF25324F)),
          SizedBox(height: 10),
          Text('Envie a primeira mensagem', style: TextStyle(color: _muted)),
        ],
      ),
    );
  }
}

class LogoTitle extends StatelessWidget {
  const LogoTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Live',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'Chat',
            style: TextStyle(color: _accent),
          ),
        ],
      ),
      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32),
    );
  }
}

class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.activeRight,
    required this.left,
    required this.right,
    required this.onChanged,
  });

  final bool activeRight;
  final String left;
  final String right;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF141A2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _segment(left, !activeRight, () => onChanged(false)),
          _segment(right, activeRight, () => onChanged(true)),
        ],
      ),
    );
  }

  Expanded _segment(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? const [BoxShadow(color: Color(0x552F83F7), blurRadius: 14)]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: active ? Colors.white : _muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF7180A0)),
        filled: true,
        fillColor: _field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: color,
      child: Text(
        initials(text),
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

String initials(String text) {
  final parts = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

Color avatarColor(String seed) {
  const colors = [
    Color(0xFFA9423A),
    Color(0xFF2B7DA7),
    Color(0xFF4540A7),
    Color(0xFF879B22),
    Color(0xFFB87925),
    Color(0xFFC83464),
    Color(0xFF35AFC5),
  ];
  final value = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return colors[value % colors.length];
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
