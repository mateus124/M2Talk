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

const String defaultApiIp = String.fromEnvironment(
  'API_IP',
  defaultValue: '10.0.2.2',
);
const int apiPort = 8000;

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
  String? _apiIp;
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
    final apiIp = prefs.getString('apiIp');
    setState(() {
      _apiIp = apiIp;
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

  Future<void> _setApiIp(String ip) async {
    final normalized = ip.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiIp', normalized);
    setState(() => _apiIp = normalized);
  }

  Future<void> _changeApiIp() async {
    final nextIp = await showDialog<String>(
      context: context,
      builder: (_) => ServerIpDialog(initialIp: _apiIp ?? defaultApiIp),
    );
    if (nextIp == null || nextIp.trim().isEmpty) return;
    await _setApiIp(nextIp);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('name');
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final apiIp = _apiIp;
    if (apiIp == null || apiIp.isEmpty) {
      return ServerIpScreen(initialIp: defaultApiIp, onSave: _setApiIp);
    }
    return _session == null
        ? AuthScreen(
            key: ValueKey('auth-$apiIp'),
            apiHost: '$apiIp:$apiPort',
            onAuthenticated: _setSession,
            onChangeServer: _changeApiIp,
          )
        : ChatShell(
            key: ValueKey('chat-$apiIp'),
            apiHost: '$apiIp:$apiPort',
            session: _session!,
            onLogout: _logout,
            onChangeServer: _changeApiIp,
          );
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

// ─── Models ──────────────────────────────────────────────────────────────────

class UserSearchResult {
  const UserSearchResult({required this.id, required this.name});

  final int id;
  final String name;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as int,
      name: (json['nome'] ?? json['name'] ?? '').toString(),
    );
  }
}

// ─── API Client ───────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient({required this.apiHost, required this.session});

  final String apiHost;
  final Session? session;
  Uri get _base => Uri.parse('http://$apiHost');
  Uri get _wsBase => Uri.parse('ws://$apiHost');

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (session != null) 'Authorization': 'Bearer ${session!.token}',
  };

  Future<Session> login(String email, String password) async {
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

  Future<void> register(String name, String email, String password) async {
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

  Future<void> addGroupMember(String groupName, String username) async {
    final res = await http.post(
      _base.replace(path: '/api/groups/$groupName/members'),
      headers: _headers,
      body: jsonEncode({'username': username}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException.fromJson(_decode(res));
    }
  }

  Future<void> sendPrivateMessage(int recipientId, String message) async {
    final res = await http.post(
      _base.replace(path: '/api/private-chat/message'),
      headers: _headers,
      body: jsonEncode({'recipient_id': recipientId, 'message': message}),
    );
    if (res.statusCode != 200) throw ApiException.fromJson(_decode(res));
  }

  Future<List<UserSearchResult>> searchUsers(String username) async {
    final res = await http.get(
      _base.replace(
        path: '/api/users/search',
        queryParameters: {'username': username},
      ),
      headers: _headers,
    );
    if (res.statusCode != 200) throw ApiException.fromJson(_decode(res));
    final list = _decode(res) as List<dynamic>;
    return list
        .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
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

// ─── Server IP Screens ────────────────────────────────────────────────────────

class ServerIpScreen extends StatefulWidget {
  const ServerIpScreen({
    super.key,
    required this.initialIp,
    required this.onSave,
  });

  final String initialIp;
  final ValueChanged<String> onSave;

  @override
  State<ServerIpScreen> createState() => _ServerIpScreenState();
}

class _ServerIpScreenState extends State<ServerIpScreen> {
  late final TextEditingController _ip;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ip = TextEditingController(text: widget.initialIp);
  }

  void _save() {
    final value = _ip.text.trim();
    if (!_isValidServer(value)) {
      setState(() => _error = 'Informe um IP valido, como 192.168.100.24');
      return;
    }
    widget.onSave(value);
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
                    const SizedBox(height: 10),
                    const Text(
                      'Conectar ao servidor',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Digite o IP do computador onde o backend esta rodando.',
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: _ip,
                      hint: '192.168.100.24',
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? 'Porta usada: $apiPort',
                      style: TextStyle(
                        color: _error == null ? _muted : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar servidor'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

class ServerIpDialog extends StatefulWidget {
  const ServerIpDialog({super.key, required this.initialIp});

  final String initialIp;

  @override
  State<ServerIpDialog> createState() => _ServerIpDialogState();
}

class _ServerIpDialogState extends State<ServerIpDialog> {
  late final TextEditingController _ip;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ip = TextEditingController(text: widget.initialIp);
  }

  void _save() {
    final value = _ip.text.trim();
    if (!_isValidServer(value)) {
      setState(() => _error = 'IP invalido');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text('Servidor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _ip,
            hint: '192.168.100.24',
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Porta usada: $apiPort',
            style: TextStyle(
              color: _error == null ? _muted : Colors.redAccent,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

bool _isValidServer(String value) {
  final input = value.trim();
  if (input.isEmpty || input.contains(':') || input.contains('/')) return false;
  final ipv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
  if (ipv4.hasMatch(input)) {
    return input.split('.').every((part) {
      final number = int.tryParse(part);
      return number != null && number >= 0 && number <= 255;
    });
  }
  return RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(input);
}

// ─── Models ───────────────────────────────────────────────────────────────────

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
    this.id,
    required this.message,
    required this.timestamp,
    required this.groupName,
    required this.senderName,
    required this.senderId,
    this.type,
  });

  final int? id;
  final String message;
  final DateTime timestamp;
  final String groupName;
  final String senderName;
  final int? senderId;
  final String? type;

  bool get isPrivate => type == 'private';

  /// For private messages the conversation key is built from both participant
  /// IDs so both sides map to the same "thread".
  String privateKey(int myId) {
    if (!isPrivate || senderId == null) return groupName;
    final ids = [myId, senderId!]..sort();
    return 'private_${ids[0]}_${ids[1]}';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final from = json['from'];
    final sender = from is Map ? from : <String, dynamic>{};
    final group =
        json['group_name'] ??
        json['conversation_name'] ??
        json['conversation_key'] ??
        'Grupo';
    return ChatMessage(
      id: json['id'] is int ? json['id'] as int : null,
      message: (json['message'] ?? json['content'] ?? json['text'] ?? '')
          .toString(),
      timestamp: parseServerTime(json['timestamp']),
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
      type: json['type']?.toString(),
    );
  }
}

DateTime parseServerTime(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return DateTime.now();
  final hasTimezone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  final normalized = hasTimezone ? raw : '${raw}Z';
  return DateTime.tryParse(normalized)?.toLocal() ?? DateTime.now();
}

// ─── Auth Screen ──────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.apiHost,
    required this.onAuthenticated,
    required this.onChangeServer,
  });

  final String apiHost;
  final ValueChanged<Session> onAuthenticated;
  final VoidCallback onChangeServer;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final ApiClient _api;
  var _register = false;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(apiHost: widget.apiHost, session: null);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_register) {
        await _api.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      }
      final session = await _api.login(_email.text.trim(), _password.text);
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: LogoTitle()),
                        IconButton(
                          tooltip: 'Servidor',
                          onPressed: widget.onChangeServer,
                          icon: const Icon(Icons.dns_outlined, color: _muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sistema de chat em tempo real',
                      style: TextStyle(color: _muted, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.apiHost,
                      style: const TextStyle(
                        color: Color(0xFF627394),
                        fontSize: 12,
                      ),
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

// ─── Chat Shell ───────────────────────────────────────────────────────────────

/// Describes what the main pane is showing.
sealed class _PaneState {}

class _PaneGroups extends _PaneState {}

class _PaneGroupChat extends _PaneState {
  _PaneGroupChat(this.group);
  final GroupInfo group;
}

class _PanePrivateChat extends _PaneState {
  _PanePrivateChat({required this.peerId, required this.peerName});
  final int peerId;
  final String peerName;
}

class ChatShell extends StatefulWidget {
  const ChatShell({
    super.key,
    required this.apiHost,
    required this.session,
    required this.onLogout,
    required this.onChangeServer,
  });

  final String apiHost;
  final Session session;
  final VoidCallback onLogout;
  final VoidCallback onChangeServer;

  @override
  State<ChatShell> createState() => _ChatShellState();
}

class _ChatShellState extends State<ChatShell> {
  late final ApiClient _api;
  WebSocketChannel? _channel;
  var _groups = <GroupInfo>[];
  var _messages = <ChatMessage>[];
  _PaneState _pane = _PaneGroups();
  var _loading = true;
  var _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(apiHost: widget.apiHost, session: widget.session);
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
            if (!_hasMessage(message)) {
              setState(() => _messages.add(message));
            }
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

  List<ChatMessage> _groupMessages(String groupName) {
    return _messages.where((m) => m.groupName == groupName).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Returns messages that belong to a private conversation between
  /// the current user and [peerId].
  List<ChatMessage> _privateMessages(int peerId) {
  final myId = widget.session.userId;
  return _messages.where((m) {
    if (!m.isPrivate) return false;

    final key = m.privateKey(myId);

    return key.contains(peerId.toString());
  }).toList()
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

  Future<void> _sendGroupMessage(String text) async {
    final pane = _pane;
    if (pane is! _PaneGroupChat || text.trim().isEmpty) return;
    try {
      await _api.joinGroup(pane.group.name);
      await _api.sendGroupMessage(pane.group.name, text.trim());
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _sendPrivateMessage(String text) async {
    final pane = _pane;
    if (pane is! _PanePrivateChat || text.trim().isEmpty) return;
    try {
      await _api.sendPrivateMessage(pane.peerId, text.trim());
      // Optimistically add message to local list
      final optimistic = ChatMessage(
        message: text.trim(),
        timestamp: DateTime.now(),
        groupName: 'private_${widget.session.userId}_${pane.peerId}',
        senderName: widget.session.name,
        senderId: widget.session.userId,
        type: 'private',
      );
      setState(() => _messages.add(optimistic));
    } catch (error) {
      _toast(error.toString());
    }
  }

  bool _hasMessage(ChatMessage message) {
    return _messages.any((current) {
      if (message.id != null && current.id == message.id) return true;
      if (current.groupName != message.groupName) return false;
      if (current.senderId != message.senderId) return false;
      if (current.message != message.message) return false;
      return current.timestamp.difference(message.timestamp).abs().inSeconds <
          15;
    });
  }

  void _openUserSearch() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UserSearchSheet(
        api: _api,
        groups: _groups,
        onPrivateChat: (user) {
          Navigator.pop(context);
          setState(() => _pane = _PanePrivateChat(
                peerId: user.id,
                peerName: user.name,
              ));
        },
      ),
    );
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
        child: _buildPane(),
      ),
    );
  }

  Widget _buildPane() {
    final pane = _pane;

    if (pane is _PaneGroupChat) {
      return ChatView(
        session: widget.session,
        title: pane.group.name,
        subtitle: 'Grupo',
        messages: _groupMessages(pane.group.name),
        onBack: () => setState(() => _pane = _PaneGroups()),
        onSend: _sendGroupMessage,
      );
    }

    if (pane is _PanePrivateChat) {
      return ChatView(
        session: widget.session,
        title: pane.peerName,
        subtitle: 'Mensagem privada',
        messages: _privateMessages(pane.peerId),
        onBack: () => setState(() => _pane = _PaneGroups()),
        onSend: _sendPrivateMessage,
        isPrivate: true,
      );
    }

    // _PaneGroups
    return ConversationList(
      session: widget.session,
      groups: _groups,
      messages: _messages,
      loading: _loading,
      wsConnected: _wsConnected,
      apiHost: widget.apiHost,
      onLogout: widget.onLogout,
      onChangeServer: widget.onChangeServer,
      onCreateGroup: _createGroup,
      onOpenUserSearch: _openUserSearch,
      onSelectGroup: (group) => setState(() => _pane = _PaneGroupChat(group)),
      onSelectPrivate: (peerId, peerName) => setState(
        () => _pane = _PanePrivateChat(peerId: peerId, peerName: peerName),
      ),
    );
  }
}

// ─── User Search Bottom Sheet ─────────────────────────────────────────────────

class UserSearchSheet extends StatefulWidget {
  const UserSearchSheet({
    super.key,
    required this.api,
    required this.groups,
    required this.onPrivateChat,
  });

  final ApiClient api;
  final List<GroupInfo> groups;
  final ValueChanged<UserSearchResult> onPrivateChat;

  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  final _query = TextEditingController();
  var _results = <UserSearchResult>[];
  var _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final text = _query.text.trim();
    if (text.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.searchUsers(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToGroup(UserSearchResult user) async {
    if (widget.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voce nao tem grupos para adicionar.')),
      );
      return;
    }

    final selected = await showDialog<GroupInfo>(
      context: context,
      builder: (_) => _GroupPickerDialog(groups: widget.groups),
    );
    if (selected == null || !mounted) return;

    try {
      await widget.api.addGroupMember(selected.name, user.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} adicionado a ${selected.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'Buscar usuários',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: _muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppTextField(
                  controller: _query,
                  hint: 'Nome do usuário...',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildResults(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      );
    }
    if (_query.text.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 48, color: Color(0xFF25324F)),
            SizedBox(height: 10),
            Text(
              'Digite um nome para buscar',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum usuário encontrado',
          style: TextStyle(color: _muted),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _results[index];
        return Container(
          decoration: BoxDecoration(
            color: _field,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            leading: InitialsAvatar(
              text: user.name,
              color: avatarColor(user.name),
            ),
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'ID: ${user.id}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Mensagem privada',
                  child: IconButton(
                    onPressed: () => widget.onPrivateChat(user),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: _accent,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Adicionar a grupo',
                  child: IconButton(
                    onPressed: () => _addToGroup(user),
                    icon: const Icon(
                      Icons.group_add_outlined,
                      color: _online,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Group Picker Dialog ──────────────────────────────────────────────────────

class _GroupPickerDialog extends StatefulWidget {
  const _GroupPickerDialog({required this.groups});

  final List<GroupInfo> groups;

  @override
  State<_GroupPickerDialog> createState() => _GroupPickerDialogState();
}

class _GroupPickerDialogState extends State<_GroupPickerDialog> {
  GroupInfo? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _panel,
      title: const Text('Adicionar ao grupo'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final group = widget.groups[index];
            final selected = _selected?.id == group.id;
            return InkWell(
              onTap: () => setState(() => _selected = group),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? _accent.withValues(alpha: 0.2) : _field,
                  border: Border.all(
                    color: selected ? _accent : _border,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(
                      text: group.name,
                      color: avatarColor(group.name),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: _accent, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

// ─── Conversation List ────────────────────────────────────────────────────────

class ConversationList extends StatefulWidget {
  const ConversationList({
    super.key,
    required this.session,
    required this.groups,
    required this.messages,
    required this.loading,
    required this.wsConnected,
    required this.apiHost,
    required this.onLogout,
    required this.onChangeServer,
    required this.onCreateGroup,
    required this.onOpenUserSearch,
    required this.onSelectGroup,
    required this.onSelectPrivate,
  });

  final Session session;
  final List<GroupInfo> groups;
  final List<ChatMessage> messages;
  final bool loading;
  final bool wsConnected;
  final String apiHost;
  final VoidCallback onLogout;
  final VoidCallback onChangeServer;
  final VoidCallback onCreateGroup;
  final VoidCallback onOpenUserSearch;
  final ValueChanged<GroupInfo> onSelectGroup;
  final void Function(int peerId, String peerName) onSelectPrivate;

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Collects distinct private conversations from message history.
  List<_PrivateThread> _privateThreads() {
    final myId = widget.session.userId;
    final threads = <String, _PrivateThread>{};

    for (final m in widget.messages) {
      if (!m.isPrivate) continue;
      final peerId = m.senderId == myId ? null : m.senderId;
      if (peerId == null) continue; // sent by me — need to figure out recipient
      final key = 'p_$peerId';
      threads.putIfAbsent(
        key,
        () => _PrivateThread(peerId: peerId, peerName: m.senderName),
      );
    }
    return threads.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.toLowerCase();
    final groups = widget.groups
        .where((g) => g.name.toLowerCase().contains(query))
        .toList();
    final threads = _privateThreads()
        .where((t) => t.peerName.toLowerCase().contains(query))
        .toList();

    return Column(
      children: [
        // ── Header ──
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
                          style: const TextStyle(
                            color: _online,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Buscar usuários',
                onPressed: widget.onOpenUserSearch,
                icon: const Icon(Icons.person_search_outlined, color: _muted),
              ),
              IconButton(
                tooltip: 'Servidor',
                onPressed: widget.onChangeServer,
                icon: const Icon(Icons.dns_outlined, color: _muted),
              ),
              IconButton(
                tooltip: 'Sair',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, color: _muted),
              ),
            ],
          ),
        ),
        // ── Search ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: AppTextField(
            controller: _search,
            hint: 'Buscar conversas...',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        // ── Tabs ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF141A2C),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: _muted,
            indicator: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x552F83F7), blurRadius: 14),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_outlined, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Grupos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Privadas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Tab Content ──
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // Groups tab
              widget.loading
                  ? const Center(child: CircularProgressIndicator())
                  : groups.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum grupo encontrado',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: groups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final last = widget.messages
                            .where((m) => m.groupName == group.name)
                            .toList()
                          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                        return ConversationTile(
                          title: group.name,
                          subtitle: last.isEmpty
                              ? 'Grupo'
                              : '${last.first.senderName}: ${last.first.message}',
                          time: last.isEmpty ? null : last.first.timestamp,
                          onTap: () => widget.onSelectGroup(group),
                        );
                      },
                    ),
              // Private tab
              threads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Color(0xFF25324F),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Sem conversas privadas',
                            style: TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: widget.onOpenUserSearch,
                            icon: const Icon(Icons.person_search_outlined),
                            label: const Text('Buscar usuário'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      itemCount: threads.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final thread = threads[index];
                        return ConversationTile(
                          title: thread.peerName,
                          subtitle: 'Mensagem privada',
                          time: null,
                          isPrivate: true,
                          onTap: () => widget.onSelectPrivate(
                            thread.peerId,
                            thread.peerName,
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
        // ── Bottom bar ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF1C2740))),
          ),
          child: Row(
            children: [
              Expanded(
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
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenUserSearch,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Buscar usuário'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    foregroundColor: const Color(0xFF88FFCB),
                    side: const BorderSide(color: Color(0xFF1E7050)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivateThread {
  const _PrivateThread({required this.peerId, required this.peerName});
  final int peerId;
  final String peerName;
}

// ─── Chat View ────────────────────────────────────────────────────────────────

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.session,
    required this.title,
    required this.subtitle,
    required this.messages,
    required this.onBack,
    required this.onSend,
    this.isPrivate = false,
  });

  final Session session;
  final String title;
  final String subtitle;
  final List<ChatMessage> messages;
  final VoidCallback onBack;
  final ValueChanged<String> onSend;
  final bool isPrivate;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    final text = _input.text;
    _input.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── AppBar ──
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
                text: widget.title,
                color: widget.isPrivate
                    ? const Color(0xFF4540A7)
                    : avatarColor(widget.title),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        if (widget.isPrivate)
                          const Icon(
                            Icons.lock_outline,
                            size: 11,
                            color: _muted,
                          ),
                        if (widget.isPrivate) const SizedBox(width: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Messages ──
        Expanded(
          child: widget.messages.isEmpty
              ? EmptyChat(isPrivate: widget.isPrivate)
              : ListView.builder(
                  controller: _scroll,
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
        // ── Input ──
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
                  hint: widget.isPrivate
                      ? 'Mensagem privada...'
                      : 'Digite uma mensagem...',
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

// ─── Message Bubble ───────────────────────────────────────────────────────────

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isPrivate)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock_outline, size: 10, color: Colors.white54),
                  ),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: mine ? Colors.white70 : _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
    this.isPrivate = false,
  });

  final String title;
  final String subtitle;
  final DateTime? time;
  final VoidCallback onTap;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            InitialsAvatar(
              text: title,
              color: isPrivate
                  ? const Color(0xFF4540A7)
                  : avatarColor(title),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isPrivate)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: _muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (time != null)
              Text(
                _formatTime(time!),
                style: const TextStyle(
                  color: Color(0xFF65779C),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialogs ──────────────────────────────────────────────────────────────────

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

// ─── Empty Chat ───────────────────────────────────────────────────────────────

class EmptyChat extends StatelessWidget {
  const EmptyChat({super.key, this.isPrivate = false});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_outline : Icons.forum_rounded,
            size: 48,
            color: const Color(0xFF25324F),
          ),
          const SizedBox(height: 10),
          Text(
            isPrivate
                ? 'Envie uma mensagem privada'
                : 'Envie a primeira mensagem',
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class LogoTitle extends StatelessWidget {
  const LogoTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Live', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'Chat', style: TextStyle(color: _accent)),
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
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

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