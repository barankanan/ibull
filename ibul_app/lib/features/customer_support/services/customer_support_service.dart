import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_support_models.dart';

class CustomerSupportService {
  CustomerSupportService._();
  static final CustomerSupportService instance = CustomerSupportService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _ticketsTable = 'support_tickets';
  static const String _messagesTable = 'support_ticket_messages';
  static const String _attachmentsTable = 'support_ticket_attachments';
  static const String _attachmentsBucket = 'support-attachments';
  static const int _maxAttachmentBytes = 5 * 1024 * 1024;

  Exception _schemaException() => Exception(
        "Destek sistemi Supabase'te hazır değil. "
        'SUPABASE_CUSTOMER_SUPPORT.sql dosyasını çalıştırın.',
      );

  Exception _friendlyException(Object error) {
    if (_isSchemaError(error)) return _schemaException();
    if (error is PostgrestException) {
      return Exception(error.message);
    }
    return Exception(error.toString());
  }

  bool _isSchemaError(Object error) {
    final message = error.toString();
    if (error is PostgrestException) {
      if (error.code == 'PGRST205') return true;
      if (message.contains(_ticketsTable) ||
          message.contains(_messagesTable) ||
          message.contains(_attachmentsTable)) {
        return true;
      }
    }
    return message.contains('does not exist') ||
        message.contains('Could not find');
  }

  String? _currentUserId() => _supabase.auth.currentUser?.id;

  Future<CustomerSupportTicket> createTicket(
    CreateCustomerSupportTicketInput input,
  ) async {
    final validation = input.validate();
    if (validation != null) throw Exception(validation);

    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('Destek talebi oluşturmak için giriş yapmalısınız.');
    }

    final user = _supabase.auth.currentUser;
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      final inserted = await _supabase
          .from(_ticketsTable)
          .insert({
            'user_id': userId,
            'user_type': 'user',
            'category': input.category,
            'subcategory': input.subcategory?.trim().isEmpty ?? true
                ? null
                : input.subcategory!.trim(),
            'subject': input.title.trim(),
            'description': input.message.trim(),
            'status': CustomerSupportStatus.reviewing.dbValue,
            'priority': input.priority.dbValue,
            'contact_preference': input.contactPreference.dbValue,
            'user_email': input.userEmail ?? user?.email,
            'user_phone': input.userPhone,
            'related_reference': input.relatedReference?.trim(),
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      final ticket = CustomerSupportTicket.fromMap(
        Map<String, dynamic>.from(inserted as Map),
      );

      await _supabase.from(_messagesTable).insert({
        'ticket_id': ticket.id,
        'sender_type': 'user',
        'sender_id': userId,
        'message': input.message.trim(),
      });

      final ticketNumber = ticket.id.replaceAll('-', '').substring(0, 8).toUpperCase();
      final updated = await _supabase
          .from(_ticketsTable)
          .update({'ticket_number': ticketNumber})
          .eq('id', ticket.id)
          .select()
          .single();

      return CustomerSupportTicket.fromMap(
        Map<String, dynamic>.from(updated as Map),
      );
    } catch (error) {
      debugPrint('[CustomerSupport] createTicket failed: $error');
      throw _friendlyException(error);
    }
  }

  Future<List<CustomerSupportTicket>> getMyTickets() async {
    final userId = _currentUserId();
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from(_ticketsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final tickets = List<Map<String, dynamic>>.from(rows as List)
          .map(CustomerSupportTicket.fromMap)
          .toList(growable: false);

      return _attachAdminPreview(tickets);
    } catch (error) {
      debugPrint('[CustomerSupport] getMyTickets failed: $error');
      throw _friendlyException(error);
    }
  }

  Future<CustomerSupportTicketDetail> getTicketDetail(String ticketId) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('Talep detayı için giriş yapmalısınız.');
    }

    try {
      final ticketRow = await _supabase
          .from(_ticketsTable)
          .select()
          .eq('id', ticketId)
          .maybeSingle();
      if (ticketRow == null) throw Exception('Talep bulunamadı.');

      final ticket = CustomerSupportTicket.fromMap(
        Map<String, dynamic>.from(ticketRow as Map),
      );

      final messagesRows = await _supabase
          .from(_messagesTable)
          .select()
          .eq('ticket_id', ticketId)
          .eq('is_internal_note', false)
          .order('created_at', ascending: true);

      final attachmentRows = await _supabase
          .from(_attachmentsTable)
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      return CustomerSupportTicketDetail(
        ticket: ticket,
        messages: List<Map<String, dynamic>>.from(messagesRows as List)
            .map(CustomerSupportMessage.fromMap)
            .toList(growable: false),
        attachments: List<Map<String, dynamic>>.from(attachmentRows as List)
            .map(CustomerSupportAttachment.fromMap)
            .toList(growable: false),
      );
    } catch (error) {
      debugPrint('[CustomerSupport] getTicketDetail failed: $error');
      throw _friendlyException(error);
    }
  }

  Future<void> addUserMessage({
    required String ticketId,
    required String message,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw Exception('Mesaj göndermek için giriş yapmalısınız.');
    }
    if (message.trim().length < 3) {
      throw Exception('Mesaj çok kısa.');
    }

    try {
      await _supabase.from(_messagesTable).insert({
        'ticket_id': ticketId,
        'sender_type': 'user',
        'sender_id': userId,
        'message': message.trim(),
      });
      await _supabase.from(_ticketsTable).update({
        'status': CustomerSupportStatus.reviewing.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', ticketId);
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<String> uploadAttachment({
    required String ticketId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.length > _maxAttachmentBytes) {
      throw Exception('Dosya boyutu 5 MB sınırını aşıyor.');
    }
    final allowed = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
    if (!allowed.contains(mimeType)) {
      throw Exception('Desteklenmeyen dosya türü.');
    }

    final userId = _currentUserId();
    if (userId == null) throw Exception('Dosya yüklemek için giriş yapın.');

    final path =
        '$userId/$ticketId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      await _supabase.storage.from(_attachmentsBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
      final fileUrl =
          _supabase.storage.from(_attachmentsBucket).getPublicUrl(path);

      await _supabase.from(_attachmentsTable).insert({
        'ticket_id': ticketId,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_type': mimeType,
        'file_size': bytes.length,
      });
      return fileUrl;
    } catch (error) {
      debugPrint('[CustomerSupport] uploadAttachment failed: $error');
      throw _friendlyException(error);
    }
  }

  Future<List<CustomerSupportTicket>> adminGetTickets({
    String? status,
    String? category,
    String? priority,
    String? search,
  }) async {
    try {
      var query = _supabase.from(_ticketsTable).select();
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (priority != null && priority.isNotEmpty) {
        query = query.eq('priority', priority);
      }
      final rows = await query.order('created_at', ascending: false);
      var tickets = List<Map<String, dynamic>>.from(rows as List)
          .map(CustomerSupportTicket.fromMap)
          .toList(growable: false);

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        tickets = tickets
            .where(
              (t) =>
                  t.title.toLowerCase().contains(q) ||
                  t.message.toLowerCase().contains(q) ||
                  t.displayTicketNumber.toLowerCase().contains(q) ||
                  (t.userEmail ?? '').toLowerCase().contains(q),
            )
            .toList(growable: false);
      }
      return tickets;
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<CustomerSupportTicketDetail> adminGetTicketDetail(
    String ticketId,
  ) async {
    try {
      final ticketRow = await _supabase
          .from(_ticketsTable)
          .select()
          .eq('id', ticketId)
          .maybeSingle();
      if (ticketRow == null) throw Exception('Talep bulunamadı.');

      final messagesRows = await _supabase
          .from(_messagesTable)
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      final attachmentRows = await _supabase
          .from(_attachmentsTable)
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at', ascending: true);

      return CustomerSupportTicketDetail(
        ticket: CustomerSupportTicket.fromMap(
          Map<String, dynamic>.from(ticketRow as Map),
        ),
        messages: List<Map<String, dynamic>>.from(messagesRows as List)
            .map(CustomerSupportMessage.fromMap)
            .toList(growable: false),
        attachments: List<Map<String, dynamic>>.from(attachmentRows as List)
            .map(CustomerSupportAttachment.fromMap)
            .toList(growable: false),
      );
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<void> adminReplyTicket({
    required String ticketId,
    required String message,
    bool internalNote = false,
  }) async {
    final adminId = _currentUserId();
    if (adminId == null) throw Exception('Admin oturumu gerekli.');
    if (message.trim().isEmpty) throw Exception('Cevap boş olamaz.');

    try {
      await _supabase.from(_messagesTable).insert({
        'ticket_id': ticketId,
        'sender_type': 'admin',
        'sender_id': adminId,
        'message': message.trim(),
        'is_internal_note': internalNote,
      });
      if (!internalNote) {
        await adminUpdateStatus(
          ticketId: ticketId,
          status: CustomerSupportStatus.answered,
        );
      }
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<void> adminRequestMoreInfo({
    required String ticketId,
    required String message,
  }) async {
    await adminReplyTicket(ticketId: ticketId, message: message);
    await adminUpdateStatus(
      ticketId: ticketId,
      status: CustomerSupportStatus.waitingUser,
    );
  }

  Future<void> adminCloseTicket({
    required String ticketId,
    CustomerSupportStatus status = CustomerSupportStatus.resolved,
    String? closingNote,
  }) async {
    if (closingNote != null && closingNote.trim().isNotEmpty) {
      await adminReplyTicket(ticketId: ticketId, message: closingNote.trim());
    }
    await adminUpdateStatus(ticketId: ticketId, status: status, close: true);
  }

  Future<void> adminUpdateStatus({
    required String ticketId,
    required CustomerSupportStatus status,
    bool close = false,
  }) async {
    try {
      final payload = <String, dynamic>{
        'status': status.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (close) {
        payload['closed_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await _supabase.from(_ticketsTable).update(payload).eq('id', ticketId);
    } catch (error) {
      throw _friendlyException(error);
    }
  }

  Future<List<CustomerSupportTicket>> _attachAdminPreview(
    List<CustomerSupportTicket> tickets,
  ) async {
    if (tickets.isEmpty) return tickets;

    try {
      final ids = tickets.map((t) => t.id).toList(growable: false);
      final rows = await _supabase
          .from(_messagesTable)
          .select('ticket_id, message, created_at, sender_type')
          .inFilter('ticket_id', ids)
          .eq('sender_type', 'admin')
          .eq('is_internal_note', false)
          .order('created_at', ascending: false);

      final previewByTicket = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final ticketId = row['ticket_id']?.toString() ?? '';
        if (ticketId.isEmpty || previewByTicket.containsKey(ticketId)) continue;
        previewByTicket[ticketId] = row['message']?.toString() ?? '';
      }

      return tickets
          .map(
            (ticket) => CustomerSupportTicket(
              id: ticket.id,
              userId: ticket.userId,
              category: ticket.category,
              subcategory: ticket.subcategory,
              title: ticket.title,
              message: ticket.message,
              status: ticket.status,
              priority: ticket.priority,
              contactPreference: ticket.contactPreference,
              createdAt: ticket.createdAt,
              updatedAt: ticket.updatedAt,
              closedAt: ticket.closedAt,
              userEmail: ticket.userEmail,
              userPhone: ticket.userPhone,
              userType: ticket.userType,
              relatedReference: ticket.relatedReference,
              ticketNumber: ticket.ticketNumber,
              lastAdminMessagePreview: previewByTicket[ticket.id],
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return tickets;
    }
  }
}
