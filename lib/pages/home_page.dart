import 'package:chat/pages/chat_page.dart';
import 'package:chat/pages/login_page.dart';
import 'package:chat/pages/profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const String routeName = 'home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _paper = Color(0xFFF5F7FB);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _ink = Color(0xFF16152E);
  static const Color _muted = Color(0xFF94A3B8);
  static const Color _mint = Color(0xFF10B981);
  static const Color _teal = Color(0xFF6C63FF);
  static const Color _coral = Color(0xFF3FA1FF);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _partnerController = TextEditingController();

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _initial(String value) {
    final text = value.trim();
    return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
  }

  Future<void> _startChat() async {
    final identifier = _partnerController.text.trim();
    if (identifier.isEmpty) {
      _showMessage('أدخل البريد أو رقم الهاتف لبدء محادثة');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showMessage('يرجى تسجيل الدخول أولًا');
      return;
    }

    if (currentUser.email != null &&
        identifier.toLowerCase() == currentUser.email!.toLowerCase()) {
      _showMessage('لا يمكنك بدء محادثة مع نفسك');
      return;
    }

    try {
      final partnerQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: identifier)
          .limit(1)
          .get();

      final phoneQuery = partnerQuery.docs.isEmpty
          ? await _firestore
                .collection('users')
                .where('phone', isEqualTo: identifier)
                .limit(1)
                .get()
          : null;

      if (!mounted) return;
      if (partnerQuery.docs.isEmpty && (phoneQuery?.docs.isEmpty ?? true)) {
        _showMessage('لم يتم العثور على مستخدم بهذا البريد أو الرقم');
        return;
      }

      final partnerDoc = partnerQuery.docs.isNotEmpty
          ? partnerQuery.docs.first
          : phoneQuery!.docs.first;
      final partnerData = partnerDoc.data();
      final partnerUid = partnerDoc.id;
      final currentUid = currentUser.uid;

      final chatId = currentUid.compareTo(partnerUid) < 0
          ? '$currentUid-$partnerUid'
          : '$partnerUid-$currentUid';
      final chatRef = _firestore.collection('chats').doc(chatId);

      if (!(await chatRef.get()).exists) {
        await chatRef.set({
          'participants': [currentUid, partnerUid],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': currentUid,
          'unreadCounts': {currentUid: 0, partnerUid: 0},
        });
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: chatId,
            partnerName:
                (partnerData['name'] as String?) ??
                (partnerData['email'] as String? ?? 'مستخدم'),
            partnerUid: partnerUid,
          ),
        ),
      );
      _partnerController.clear();
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'حدث خطأ أثناء بدء المحادثة');
    } catch (_) {
      _showMessage('تعذر بدء المحادثة، حاول مرة أخرى');
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginPage.routeName,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج، حاول مرة أخرى')),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: _ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _displayName(Map<String, dynamic> data) {
    final name = (data['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = (data['email'] as String?) ?? '';
    return email.contains('@') ? email.split('@').first : 'مستخدم';
  }

  Widget _avatar(
    String name, {
    double size = 52,
    Color background = _ink,
    Color foreground = Colors.white,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160E202B),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _initial(name),
        style: TextStyle(
          color: foreground,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  PreferredSizeWidget _chatStyleAppBar(User? user) {
    final email = user?.email ?? '';
    final name = email.contains('@') ? email.split('@').first : 'صديق';

    return PreferredSize(
      preferredSize: const Size.fromHeight(78),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF16152E), Color(0xFF3C2E78), Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: Text(
                _initial(name),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مساحتك الخاصة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الملف الشخصي',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16152E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F14232D),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تواصل ببساطة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'ابحث عن شخص وابدأ حديثًا يستحق أن يُحكى.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Color(0xFF16152E),
              size: 29,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.search_rounded, color: _teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _partnerController,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _startChat(),
              decoration: const InputDecoration(
                hintText: 'ابحث بالبريد أو رقم الهاتف',
                hintStyle: TextStyle(color: _muted, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _startChat,
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 45),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String caption) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E5E1)),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              color: _muted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E5E1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _muted, size: 21),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _contacts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 112,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final contacts = (snapshot.data?.docs ?? [])
            .where((doc) => doc.id != _currentUid)
            .map((doc) {
              final data = doc.data();
              return {
                'name': _displayName(data),
                'email': (data['email'] as String?) ?? '',
              };
            })
            .toList();

        if (contacts.isEmpty) {
          return _emptyCard(
            'لا يوجد مستخدمون جدد حاليًا',
            Icons.people_outline,
          );
        }

        return SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            itemCount: contacts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final name = contact['name'] as String;
              return GestureDetector(
                onTap: () {
                  _partnerController.text = contact['email'] as String;
                  _startChat();
                },
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _avatar(name, size: 58, background: _ink),
                          Positioned(
                            left: 0,
                            bottom: 1,
                            child: Container(
                              width: 15,
                              height: 15,
                              decoration: BoxDecoration(
                                color: _mint,
                                shape: BoxShape.circle,
                                border: Border.all(color: _paper, width: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _chatPreview(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final participants = List<String>.from(data['participants'] ?? const []);
    final otherUid = participants.firstWhere(
      (id) => id != _currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return null;

    final partnerDoc = await _firestore.collection('users').doc(otherUid).get();
    final partnerData = partnerDoc.data() ?? <String, dynamic>{};
    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final unread = unreadCounts[_currentUid];

    return {
      'id': doc.id,
      'uid': otherUid,
      'name': _displayName(partnerData),
      'last': (data['lastMessage'] as String?) ?? '',
      'unread': unread is num ? unread.toInt() : 0,
    };
  }

  Widget _chats() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyCard('تعذر تحميل المحادثات حاليًا', Icons.cloud_off);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyCard(
            'لا توجد محادثات بعد، ابدأ أول محادثة الآن',
            Icons.forum_outlined,
          );
        }

        return FutureBuilder<List<Map<String, dynamic>?>>(
          future: Future.wait(docs.map(_chatPreview)),
          builder: (context, futureSnapshot) {
            if (!futureSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final chats = futureSnapshot.data!
                .whereType<Map<String, dynamic>>()
                .toList();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final chat = chats[index];
                final name = chat['name'] as String;
                final last = chat['last'] as String;
                final unread = chat['unread'] as int;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            chatId: chat['id'] as String,
                            partnerName: name,
                            partnerUid: chat['uid'] as String,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E5E1)),
                      ),
                      child: Row(
                        children: [
                          _avatar(
                            name,
                            size: 54,
                            background: index.isEven ? _teal : _ink,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  last.isEmpty ? 'ابدأ محادثة جديدة' : last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: _muted,
                                size: 15,
                              ),
                              const SizedBox(height: 9),
                              if (unread > 0)
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: _coral,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _partnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول مرة أخرى')),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: _chatStyleAppBar(user),
          extendBody: true,
          backgroundColor: const Color(0xFFE7F2FF),
          body: SizedBox.expand(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE6E7FF),
                    Color(0xFFF8F9FF),
                    Color(0xFFE7F2FF),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _introCard(),
                      _searchCard(),
                      _sectionTitle(
                        'متاحون الآن',
                        'اختر شخصًا وابدأ الحديث فورًا',
                      ),
                      _contacts(),
                      _sectionTitle('محادثاتك', 'كل رسائلك '),
                      _chats(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
