import 'package:supabase_flutter/supabase_flutter.dart';

enum TicketStatus { open, inProgress, closed, resolved }

enum TicketPriority { low, medium, high }

class SupportTicket {
  final String id;
  final String userId;
  final String userType; // 'seller', 'user'
  final String category;
  final String subject;
  final String description;
  final TicketStatus status;
  final TicketPriority priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? assignedTo; // Admin ID

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userType,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
    this.assignedTo,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map, String id) {
    return SupportTicket(
      id: id,
      userId: map['user_id'] ?? map['userId'] ?? '',
      userType: map['user_type'] ?? map['userType'] ?? 'user',
      category: map['category'] ?? 'Genel',
      subject: map['subject'] ?? '',
      description: map['description'] ?? '',
      status: TicketStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'open'),
        orElse: () => TicketStatus.open,
      ),
      priority: TicketPriority.values.firstWhere(
        (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => TicketPriority.medium,
      ),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      assignedTo: map['assigned_to'] ?? map['assignedTo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'user_type': userType,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'assigned_to': assignedTo,
    };
  }
}

class SupportService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'support_tickets';

  Exception _friendlySchemaException() {
    return Exception(
      "Destek sistemi Supabase'te hazir degil. 'support_tickets' tablosunu olusturmaniz gerekiyor.",
    );
  }

  Object _mapError(Object error) {
    final details = error is PostgrestException ? '${error.details ?? ''}' : '';
    if (error is PostgrestException &&
        (error.code == 'PGRST205' ||
            error.message.contains(_tableName) ||
            details.contains(_tableName))) {
      return _friendlySchemaException();
    }
    return error;
  }

  // Create a new ticket
  Future<void> createTicket({
    required String userId,
    required String userType,
    required String category,
    required String subject,
    required String description,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    try {
      await _supabase.from(_tableName).insert({
        'user_id': userId,
        'user_type': userType,
        'category': category,
        'subject': subject,
        'description': description,
        'status': TicketStatus.open.name,
        'priority': priority.name,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      throw _mapError(error);
    }
  }

  // Get tickets for a specific user (Seller/User)
  Stream<List<SupportTicket>> getUserTickets(String userId) {
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (maps) => maps
              .map((map) => SupportTicket.fromMap(map, map['id'].toString()))
              .toList(),
        )
        .handleError((error) {
          throw _mapError(error);
        });
  }

  Future<List<SupportTicket>> getUserTicketsSnapshot(String userId) async {
    try {
      final rows = await _supabase
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List<dynamic>)
          .map((map) => SupportTicket.fromMap(map, map['id'].toString()))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error);
    }
  }

  // Get all tickets (Admin)
  Stream<List<SupportTicket>> getAllTickets() {
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (maps) => maps
              .map((map) => SupportTicket.fromMap(map, map['id'].toString()))
              .toList(),
        )
        .handleError((error) {
          throw _mapError(error);
        });
  }

  Future<List<SupportTicket>> getAllTicketsSnapshot() async {
    try {
      final rows = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List<dynamic>)
          .map((map) => SupportTicket.fromMap(map, map['id'].toString()))
          .toList(growable: false);
    } catch (error) {
      throw _mapError(error);
    }
  }

  // Update ticket status
  Future<void> updateTicketStatus(String ticketId, TicketStatus status) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ticketId);
    } catch (error) {
      throw _mapError(error);
    }
  }
}
