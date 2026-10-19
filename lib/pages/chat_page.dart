import 'dart:io';

import 'package:chat/utils/message_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

// Helper to format message time
String formatMessageTime(dynamic timestamp) {
  if (timestamp == null) {
    return '';
  }

  DateTime dateTime;
  if (timestamp is Timestamp) {
    dateTime = timestamp.toDate();
  } else if (timestamp is DateTime) {
    dateTime = timestamp;
  } else {
    return '';
  }

  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final period = dateTime.hour >= 12 ? 'م' : 'ص';
  return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
}

// Check if two dates are the same day
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

// Gorgeous Full-Screen Image Viewer with Interactive Pinch-To-Zoom and Hero Animations
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Pulse Online Status Indicator
class PulsingStatusIndicator extends StatefulWidget {
  const PulsingStatusIndicator({super.key});

  @override
  State<PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981), // Emerald Green
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF10B981,
                ).withOpacity(0.5 * _controller.value),
                blurRadius: 6 * _controller.value,
                spreadRadius: 3 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Modern Interactive Message Bubble Widget
class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final String messageId;
  final bool isMine;
  final String currentUid;
  final String partnerName;
  final Function(String messageId, String? text, String type) onSwipeReply;
  final Function(String messageId, String? text) onEdit;
  final Function(String messageId) onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.messageId,
    required this.isMine,
    required this.currentUid,
    required this.partnerName,
    required this.onSwipeReply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideController.addListener(() {
      setState(() {
        _dragOffset = _dragOffset * (1.0 - _slideController.value);
      });
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  // Generates simulated visual wave bars for audio/voice notes
  Widget _buildAudioWaveform(bool isMine) {
    final heights = [
      10.0,
      16.0,
      8.0,
      24.0,
      14.0,
      18.0,
      6.0,
      22.0,
      12.0,
      16.0,
      10.0,
      20.0,
      8.0,
      14.0,
      6.0,
    ];
    final barColor = isMine
        ? Colors.white.withOpacity(0.6)
        : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights
          .map(
            (h) => Container(
              width: 2.5,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          )
          .toList(),
    );
  }

  // Parses mentions inline inside text, styling @username nicely
  Widget _buildMessageText({
    required String text,
    required bool isMine,
    required List<dynamic>? mentions,
  }) {
    final TextStyle baseStyle = TextStyle(
      fontSize: 15,
      color: isMine ? Colors.white : const Color(0xFF1E293B),
      height: 1.4,
    );

    if (mentions == null || mentions.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final List<InlineSpan> spans = [];
    final RegExp regex = RegExp(r'(@[^\s@]+)');
    int lastIndex = 0;

    for (final Match match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final String mentionText = match.group(0)!;
      spans.add(
        TextSpan(
          text: mentionText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isMine ? Colors.amberAccent : const Color(0xFF6C63FF),
            backgroundColor: isMine
                ? Colors.white.withOpacity(0.15)
                : const Color(0xFF6C63FF).withOpacity(0.08),
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  // Premium Custom Audio Bubble Design
  Widget _buildAudioBubble(bool isMine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? Colors.white.withOpacity(0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow_rounded,
            color: isMine ? Colors.white : const Color(0xFF6C63FF),
            size: 26,
          ),
          const SizedBox(width: 8),
          _buildAudioWaveform(isMine),
          const SizedBox(width: 10),
          Text(
            'صوت',
            style: TextStyle(
              fontSize: 14,
              color: isMine ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Premium Custom Video Bubble Design
  Widget _buildVideoBubble(bool isMine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? Colors.white.withOpacity(0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_rounded,
            color: isMine ? Colors.white : const Color(0xFF6C63FF),
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            'فيديو',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isMine ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // Reply Block displayed inside the message bubble
  Widget _buildReplyPreview(bool isMine) {
    final replyText = widget.message['replyToText']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withOpacity(0.12)
            : const Color(0xFF6C63FF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(
            color: isMine ? Colors.white70 : const Color(0xFF6C63FF),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رد',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMine ? Colors.white70 : const Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMine
                  ? Colors.white.withOpacity(0.9)
                  : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // Action Bottom Sheet triggered on long press (Modern Overlay)
  void _showOptionsBottomSheet(BuildContext context) {
    final message = widget.message;
    final messageId = widget.messageId;
    final isMine = widget.isMine;
    final messageType = message['type']?.toString() ?? 'text';
    final messageText = message['text']?.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  messageType == 'text' ? (messageText ?? '') : 'رسالة وسائط',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.reply_rounded,
                  color: Color(0xFF6C63FF),
                ),
                title: const Text(
                  'الرد على الرسالة',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSwipeReply(messageId, messageText, messageType);
                },
              ),
              if (isMine && messageType == 'text')
                ListTile(
                  leading: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF3FA1FF),
                  ),
                  title: const Text(
                    'تعديل الرسالة',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit(messageId, messageText);
                  },
                ),
              if (isMine)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'حذف الرسالة',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete(messageId);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final messageId = widget.messageId;
    final isMine = widget.isMine;
    final messageType = message['type']?.toString() ?? 'text';
    final timeLabel = formatMessageTime(message['timestamp']);
    final isRead = message['status'] == 'read';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      child: Stack(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Fading Slide-To-Reply Action Indicator
          if (_dragOffset.abs() > 10)
            Positioned(
              left: isMine ? null : 16,
              right: isMine ? 16 : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: (_dragOffset.abs() / 60).clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Color(0xFF6C63FF),
                    size: 20,
                  ),
                ),
              ),
            ),

          // Message Bubble Card
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final maxDrag = 80.0;
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dx).clamp(
                  isMine ? -maxDrag : 0.0,
                  isMine ? 0.0 : maxDrag,
                );
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragOffset.abs() > 50) {
                widget.onSwipeReply(
                  messageId,
                  message['text']?.toString(),
                  messageType,
                );
              }
              _slideController.forward(from: 0.0);
            },
            onLongPress: () {
              HapticFeedback.lightImpact();
              _showOptionsBottomSheet(context);
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF5A52E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMine ? 20 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: isMine
                      ? null
                      : Border.all(color: Colors.grey.shade200, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply preview block inside bubble
                    if (message['replyToText'] != null &&
                        message['replyToText'].toString().isNotEmpty)
                      _buildReplyPreview(isMine),

                    // Media Contents
                    if (messageType == 'image' && message['mediaUrl'] != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: message['mediaUrl'],
                                tag: messageId,
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: messageId,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              message['mediaUrl'],
                              width: 230,
                              height: 170,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 230,
                                      height: 170,
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      )
                    else if (messageType == 'video' &&
                        message['mediaUrl'] != null)
                      _buildVideoBubble(isMine)
                    else if (messageType == 'audio' &&
                        message['mediaUrl'] != null)
                      _buildAudioBubble(isMine)
                    else
                      _buildMessageText(
                        text: message['text']?.toString() ?? '',
                        isMine: isMine,
                        mentions: message['mentions'],
                      ),

                    const SizedBox(height: 6),

                    // Time and Read checkmark status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Spacer(),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine
                                ? Colors.white.withOpacity(0.65)
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 14,
                            color: isRead
                                ? const Color(0xFF38BDF8)
                                : Colors.white60,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Main Chat Page Widget
class ChatPage extends StatefulWidget {
  final String chatId;
  final String partnerName;
  final String partnerUid;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.partnerName,
    required this.partnerUid,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  bool _showEmojiPicker = false;
  bool _isUploading = false;
  bool _isRecordingAudio = false;
  String? _replyingToMessageId;
  String? _replyingToText;
  String? _editingMessageId;
  String? _mentionQuery;
  List<String> _mentionOptions = [];

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _messagesStream = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureChatMetadata();
      _markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureChatMetadata() async {
    if (_currentUid.isEmpty) return;

    final chatRef = _firestore.collection('chats').doc(widget.chatId);
    await chatRef.set({
      'participants': [widget.partnerUid, _currentUid],
    }, SetOptions(merge: true));

    await chatRef.update({'unreadCounts.$_currentUid': 0});
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUid.isEmpty) return;

    final incomingMessages = await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _currentUid)
        .get();

    final unreadDocs = incomingMessages.docs.where((doc) {
      final status = doc.data()['status'];
      return status != 'read';
    }).toList();

    if (unreadDocs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unreadDocs) {
      batch.update(doc.reference, {
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    await _firestore.collection('chats').doc(widget.chatId).update({
      'unreadCounts.$_currentUid': 0,
    });
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'text': text,
      'senderId': _currentUid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': 'sent',
      'replyTo': _replyingToMessageId,
      'replyToText': _replyingToText,
      'mentions': extractMentions(text),
    };

    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    await _firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': text,
      'lastMessageType': 'text',
      'lastMessagePreview': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _currentUid,
      'unreadCounts.${widget.partnerUid}': FieldValue.increment(1),
    });

    _messageController.clear();
    _showEmojiPicker = false;
    _replyingToMessageId = null;
    _replyingToText = null;
    _mentionQuery = null;
    _mentionOptions = [];
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sendMediaMessage({
    required String type,
    required String mediaUrl,
  }) async {
    final mediaLabel = switch (type) {
      'image' => 'صورة',
      'video' => 'فيديو',
      'audio' => 'رسالة صوتية',
      _ => 'وسائط',
    };

    final messageData = {
      'senderId': _currentUid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'mediaUrl': mediaUrl,
      'status': 'sent',
      'text': mediaLabel,
    };

    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    await _firestore.collection('chats').doc(widget.chatId).set({
      'lastMessage': mediaLabel,
      'lastMessageType': type,
      'lastMessagePreview': mediaLabel,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': _currentUid,
      'unreadCounts.${widget.partnerUid}': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _editMessage(String messageId) async {
    final updatedText = _messageController.text.trim();
    if (updatedText.isEmpty) return;

    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': updatedText,
          'editedAt': FieldValue.serverTimestamp(),
        });

    _messageController.clear();
    _editingMessageId = null;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteMessage(String messageId) async {
    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _uploadMediaFile({
    required String type,
    required File file,
    required String originalName,
  }) async {
    if (_currentUid.isEmpty || _isUploading) return;

    try {
      if (!mounted) return;
      setState(() => _isUploading = true);

      final extension = originalName.contains('.')
          ? originalName.substring(originalName.lastIndexOf('.'))
          : '';
      final uniqueName =
          '${DateTime.now().millisecondsSinceEpoch}_$_currentUid$extension';
      final uploadRef = _storage.ref().child(
        'chats/${widget.chatId}/$type/$uniqueName',
      );

      final uploadSnapshot = await uploadRef.putFile(file);
      final downloadUrl = await uploadSnapshot.ref.getDownloadURL();
      await _sendMediaMessage(type: type, mediaUrl: downloadUrl);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر إرسال الوسائط: ${error.message ?? 'تحقق من إعدادات Firebase Storage'}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر رفع الملف، حاول مرة أخرى')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickAndUploadMedia(String type, {ImageSource? source}) async {
    if (_currentUid.isEmpty || _isUploading) return;

    try {
      File? file;
      String? originalName;

      if (type == 'image') {
        final pickedFile = await _imagePicker.pickImage(
          source: source ?? ImageSource.gallery,
          imageQuality: 88,
        );
        if (pickedFile == null) return;
        file = File(pickedFile.path);
        originalName = pickedFile.name;
      } else if (type == 'video') {
        final pickedFile = await _imagePicker.pickVideo(
          source: source ?? ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );
        if (pickedFile == null) return;
        file = File(pickedFile.path);
        originalName = pickedFile.name;
      } else {
        final result = await FilePicker.pickFiles(type: FileType.audio);
        final pickedFile = result?.files.single;
        if (pickedFile == null || pickedFile.path == null) return;
        file = File(pickedFile.path!);
        originalName = pickedFile.name;
      }

      if (file == null || originalName == null) return;
      await _uploadMediaFile(
        type: type,
        file: file,
        originalName: originalName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختيار الملف، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
        ],
        allowMultiple: false,
      );

      final filePath = result?.files.single.path;
      final fileName = result?.files.single.name;
      if (filePath == null || fileName == null) return;

      await _uploadMediaFile(
        type: 'document',
        file: File(filePath),
        originalName: fileName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختيار المستند، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isUploading || _isRecordingAudio) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يحتاج التطبيق إلى إذن الميكروفون لتسجيل الصوت'),
          ),
        );
        return;
      }

      final recordingsDir = Directory.systemTemp.path;
      final path =
          '$recordingsDir/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() => _isRecordingAudio = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جارٍ التسجيل… اسحب للأعلى للإرسال')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر بدء التسجيل، تأكد من إذن الميكروفون'),
        ),
      );
    }
  }

  Future<void> _stopVoiceRecordingAndSend() async {
    if (_isUploading || !_isRecordingAudio) return;

    try {
      final recordedPath = await _audioRecorder.stop();
      if (recordedPath == null || recordedPath.isEmpty) {
        setState(() => _isRecordingAudio = false);
        return;
      }

      final recordedFile = File(recordedPath);
      if (!await recordedFile.exists()) {
        setState(() => _isRecordingAudio = false);
        return;
      }

      setState(() => _isRecordingAudio = false);
      await _uploadMediaFile(
        type: 'audio',
        file: recordedFile,
        originalName: 'voice_note.m4a',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRecordingAudio = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنهاء التسجيل، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingAudio) {
      await _stopVoiceRecordingAndSend();
    } else {
      await _startVoiceRecording();
    }
  }

  Future<void> _loadMentionOptions() async {
    final contactsSnapshot = await _firestore.collection('users').get();
    final suggestions = contactsSnapshot.docs
        .where((doc) => doc.id != _currentUid)
        .map((doc) {
          final data = doc.data();
          return (data['name'] as String?) ?? 'User';
        })
        .toList();
    if (!mounted) return;
    setState(() => _mentionOptions = suggestions);
  }

  void _startReplyToMessage({
    required String messageId,
    required String? messageText,
    required String messageType,
  }) {
    final replyText = switch (messageType) {
      'image' => 'صورة',
      'video' => 'فيديو',
      'audio' => 'رسالة صوتية',
      _ =>
        messageText?.trim().isNotEmpty == true ? messageText!.trim() : 'رسالة',
    };

    setState(() {
      _replyingToMessageId = messageId;
      _replyingToText = replyText;
      _editingMessageId = null;
      _showEmojiPicker = false;
    });
  }

  void _startEditMessage({
    required String messageId,
    required String? messageText,
  }) {
    setState(() {
      _editingMessageId = messageId;
      _messageController.text = messageText ?? '';
      _replyingToMessageId = null;
      _replyingToText = null;
      _showEmojiPicker = false;
    });
  }

  void _selectMention(String name) {
    final text = _messageController.text;
    final lastAtIndex = text.lastIndexOf('@');
    if (lastAtIndex != -1) {
      final prefix = text.substring(0, lastAtIndex);
      _messageController.text = '$prefix@$name ';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    }
    _mentionQuery = null;
    setState(() {});
  }

  Widget _buildDateDivider(DateTime dateTime) {
    String text = '';
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (isSameDay(dateTime, now)) {
      text = 'اليوم';
    } else if (isSameDay(dateTime, yesterday)) {
      text = 'أمس';
    } else {
      text = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyComposerPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الرد على الرسالة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingToText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _replyingToMessageId = null;
                _replyingToText = null;
              });
            },
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditComposerPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_rounded, color: Color(0xFF3FA1FF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تعديل الرسالة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3FA1FF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _messageController.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _editingMessageId = null;
                _messageController.clear();
              });
            },
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionCompleter() {
    final filteredOptions = _mentionOptions
        .where(
          (option) =>
              option.toLowerCase().contains(_mentionQuery!.toLowerCase()),
        )
        .toList();

    if (filteredOptions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filteredOptions.length,
          itemBuilder: (context, index) {
            final option = filteredOptions[index];
            return GestureDetector(
              onTap: () => _selectMention(option),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF6C63FF),
                      child: Text(
                        option.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C63FF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'إرسال وسائط',
                    style: TextStyle(
                      color: Color(0xFF16152E),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _attachmentTile(
                        icon: Icons.photo_library_rounded,
                        label: 'صورة',
                        color: const Color(0xFF6C63FF),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndUploadMedia('image');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _attachmentTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'كاميرا',
                        color: const Color(0xFF3FA1FF),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndUploadMedia(
                            'image',
                            source: ImageSource.camera,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _attachmentTile(
                        icon: Icons.videocam_rounded,
                        label: 'فيديو',
                        color: const Color(0xFF3FA1FF),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndUploadMedia('video');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _attachmentTile(
                        icon: Icons.description_rounded,
                        label: 'مستند',
                        color: const Color(0xFF6C63FF),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickDocument();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _attachmentTile(
                        icon: _isRecordingAudio
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        label: _isRecordingAudio ? 'إيقاف' : 'صوت',
                        color: const Color(0xFF3FA1FF),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _toggleVoiceRecording();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _attachmentTile(
                        icon: Icons.audiotrack_rounded,
                        label: 'ملف صوتي',
                        color: const Color(0xFF6C63FF),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndUploadMedia('audio');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.26),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.14),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16152E).withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToText != null) _buildReplyComposerPreview(),
          if (_editingMessageId != null) _buildEditComposerPreview(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'الإيموجي',
                  icon: Icon(
                    _showEmojiPicker
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_outlined,
                    color: const Color(0xFF6C63FF),
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                  },
                ),
                IconButton(
                  tooltip: 'إرسال وسائط',
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF6C63FF),
                    size: 27,
                  ),
                  onPressed: _showAttachmentMenu,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE6E9F5)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      textDirection: TextDirection.rtl,
                      onChanged: (value) {
                        final match = RegExp(r'@([^\s@]+)$').firstMatch(value);
                        if (match != null) {
                          _mentionQuery = match.group(1)?.trim();
                          if (_mentionQuery != null &&
                              _mentionQuery!.isNotEmpty) {
                            _loadMentionOptions();
                          }
                        } else {
                          _mentionQuery = null;
                          _mentionOptions = [];
                        }
                        setState(() {});
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) {
                        if (_editingMessageId != null) {
                          _editMessage(_editingMessageId!);
                        } else {
                          _sendTextMessage();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (_messageController.text.trim().isEmpty &&
                        !_isRecordingAudio &&
                        details.delta.dy < -18) {
                      _startVoiceRecording();
                    }
                  },
                  onVerticalDragEnd: (_) {
                    if (_isRecordingAudio) {
                      _stopVoiceRecordingAndSend();
                    }
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3FA1FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.26),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: _messageController.text.trim().isEmpty
                          ? 'اسحب للأعلى للتسجيل الصوتي'
                          : 'إرسال',
                      icon: Icon(
                        _isRecordingAudio
                            ? Icons.mic_rounded
                            : Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        if (_messageController.text.trim().isEmpty) {
                          if (_isRecordingAudio) {
                            _stopVoiceRecordingAndSend();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'اسحب زر الإرسال للأعلى لتسجيل رسالة صوتية',
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        if (_editingMessageId != null) {
                          _editMessage(_editingMessageId!);
                        } else {
                          _sendTextMessage();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          toolbarHeight: 86,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF16152E),
                  Color(0xFF3C2E78),
                  Color(0xFF6C63FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: Colors.white24, height: 1),
          ),
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: IconButton(
                tooltip: 'رجوع',
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          title: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3FA1FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.partnerName.isNotEmpty
                            ? widget.partnerName.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: -1,
                      bottom: -1,
                      child: PulsingStatusIndicator(),
                    ),
                  ],
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'متصل الآن',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            _headerAction(
              icon: Icons.call_outlined,
              tooltip: 'اتصال',
              onPressed: () {},
            ),
            _headerAction(
              icon: Icons.more_horiz_rounded,
              tooltip: 'خيارات',
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8F9FF), Color(0xFFEFF3FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C63FF),
                          ),
                        ),
                      );
                    }

                    final messages = snapshot.data?.docs ?? [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFF6C63FF).withOpacity(0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF16152E,
                                ).withOpacity(0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFF3FA1FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.forum_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'مساحتكم الخاصة',
                                style: TextStyle(
                                  color: Color(0xFF16152E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'لا توجد رسائل بعد\nابدأ حديثًا لطيفًا الآن',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade400,
                                  height: 1.5,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageDoc = messages[index];
                        final message = messageDoc.data();
                        final messageId = messageDoc.id;
                        final isMine = message['senderId'] == _currentUid;

                        Widget? dateDivider;
                        if (index == messages.length - 1) {
                          final timestamp = message['timestamp'];
                          if (timestamp != null) {
                            final date = timestamp is Timestamp
                                ? timestamp.toDate()
                                : timestamp as DateTime;
                            dateDivider = _buildDateDivider(date);
                          }
                        } else {
                          final currentTimestamp = message['timestamp'];
                          final nextTimestamp = messages[index + 1]
                              .data()['timestamp'];
                          if (currentTimestamp != null &&
                              nextTimestamp != null) {
                            final currentDate = currentTimestamp is Timestamp
                                ? currentTimestamp.toDate()
                                : currentTimestamp as DateTime;
                            final nextDate = nextTimestamp is Timestamp
                                ? nextTimestamp.toDate()
                                : nextTimestamp as DateTime;
                            if (!isSameDay(currentDate, nextDate)) {
                              dateDivider = _buildDateDivider(currentDate);
                            }
                          }
                        }

                        final bubble = MessageBubble(
                          message: message,
                          messageId: messageId,
                          isMine: isMine,
                          currentUid: _currentUid,
                          partnerName: widget.partnerName,
                          onSwipeReply: (msgId, msgText, msgType) {
                            _startReplyToMessage(
                              messageId: msgId,
                              messageText: msgText,
                              messageType: msgType,
                            );
                          },
                          onEdit: (msgId, msgText) {
                            _startEditMessage(
                              messageId: msgId,
                              messageText: msgText,
                            );
                          },
                          onDelete: (msgId) {
                            _deleteMessage(msgId);
                          },
                        );

                        if (dateDivider != null) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [dateDivider, bubble],
                          );
                        }

                        return bubble;
                      },
                    );
                  },
                ),
              ),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  color: Colors.grey.shade50,
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'جارٍ رفع الوسائط...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_mentionQuery != null &&
                  _mentionQuery!.isNotEmpty &&
                  _mentionOptions.isNotEmpty)
                _buildMentionCompleter(),
              _buildChatComposer(),
              if (_showEmojiPicker)
                SizedBox(
                  height: 280,
                  child: EmojiPicker(
                    textEditingController: _messageController,
                    config: const Config(height: 280),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
