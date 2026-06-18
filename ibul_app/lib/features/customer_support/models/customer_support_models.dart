enum CustomerSupportStatus {
  open,
  reviewing,
  answered,
  waitingUser,
  resolved,
  closed,
  rejected;

  static CustomerSupportStatus fromDb(String? raw) {
    final normalized = (raw ?? 'open').trim();
    switch (normalized) {
      case 'reviewing':
      case 'in_progress':
        return CustomerSupportStatus.reviewing;
      case 'answered':
        return CustomerSupportStatus.answered;
      case 'waiting_user':
        return CustomerSupportStatus.waitingUser;
      case 'resolved':
        return CustomerSupportStatus.resolved;
      case 'closed':
        return CustomerSupportStatus.closed;
      case 'rejected':
        return CustomerSupportStatus.rejected;
      default:
        return CustomerSupportStatus.open;
    }
  }

  String get dbValue {
    switch (this) {
      case CustomerSupportStatus.waitingUser:
        return 'waiting_user';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case CustomerSupportStatus.open:
        return 'Açık';
      case CustomerSupportStatus.reviewing:
        return 'İncelemede';
      case CustomerSupportStatus.answered:
        return 'Cevaplandı';
      case CustomerSupportStatus.waitingUser:
        return 'Ek bilgi istendi';
      case CustomerSupportStatus.resolved:
        return 'Çözüldü';
      case CustomerSupportStatus.closed:
        return 'Kapatıldı';
      case CustomerSupportStatus.rejected:
        return 'Reddedildi';
    }
  }
}

enum CustomerSupportPriority {
  low,
  normal,
  high;

  static CustomerSupportPriority fromDb(String? raw) {
    switch ((raw ?? 'normal').trim()) {
      case 'low':
        return CustomerSupportPriority.low;
      case 'high':
        return CustomerSupportPriority.high;
      case 'medium':
      default:
        return CustomerSupportPriority.normal;
    }
  }

  String get dbValue => name == 'normal' ? 'normal' : name;

  String get label {
    switch (this) {
      case CustomerSupportPriority.low:
        return 'Düşük';
      case CustomerSupportPriority.normal:
        return 'Normal';
      case CustomerSupportPriority.high:
        return 'Yüksek';
    }
  }
}

enum CustomerSupportContactPreference {
  inApp,
  email,
  phone;

  static CustomerSupportContactPreference fromDb(String? raw) {
    switch ((raw ?? 'in_app').trim()) {
      case 'email':
        return CustomerSupportContactPreference.email;
      case 'phone':
        return CustomerSupportContactPreference.phone;
      default:
        return CustomerSupportContactPreference.inApp;
    }
  }

  String get dbValue {
    switch (this) {
      case CustomerSupportContactPreference.inApp:
        return 'in_app';
      case CustomerSupportContactPreference.email:
        return 'email';
      case CustomerSupportContactPreference.phone:
        return 'phone';
    }
  }

  String get label {
    switch (this) {
      case CustomerSupportContactPreference.inApp:
        return 'Uygulama içi yanıt';
      case CustomerSupportContactPreference.email:
        return 'E-posta';
      case CustomerSupportContactPreference.phone:
        return 'Telefon';
    }
  }
}

class CustomerSupportTicket {
  const CustomerSupportTicket({
    required this.id,
    required this.userId,
    required this.category,
    required this.subcategory,
    required this.title,
    required this.message,
    required this.status,
    required this.priority,
    required this.contactPreference,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.userEmail,
    this.userPhone,
    this.userType = 'user',
    this.relatedReference,
    this.ticketNumber,
    this.lastAdminMessagePreview,
  });

  final String id;
  final String userId;
  final String userType;
  final String category;
  final String subcategory;
  final String title;
  final String message;
  final CustomerSupportStatus status;
  final CustomerSupportPriority priority;
  final CustomerSupportContactPreference contactPreference;
  final String? userEmail;
  final String? userPhone;
  final String? relatedReference;
  final String? ticketNumber;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? lastAdminMessagePreview;

  String get displayTicketNumber =>
      ticketNumber ?? id.replaceAll('-', '').substring(0, 8).toUpperCase();

  factory CustomerSupportTicket.fromMap(Map<String, dynamic> map) {
    return CustomerSupportTicket(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userType: map['user_type']?.toString() ?? 'user',
      category: map['category']?.toString() ?? 'other',
      subcategory: map['subcategory']?.toString() ?? '',
      title: map['subject']?.toString() ?? map['title']?.toString() ?? '',
      message: map['description']?.toString() ?? map['message']?.toString() ?? '',
      status: CustomerSupportStatus.fromDb(map['status']?.toString()),
      priority: CustomerSupportPriority.fromDb(map['priority']?.toString()),
      contactPreference: CustomerSupportContactPreference.fromDb(
        map['contact_preference']?.toString(),
      ),
      userEmail: map['user_email']?.toString(),
      userPhone: map['user_phone']?.toString(),
      relatedReference: map['related_reference']?.toString(),
      ticketNumber: map['ticket_number']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      closedAt: DateTime.tryParse(map['closed_at']?.toString() ?? ''),
      lastAdminMessagePreview: map['last_admin_message_preview']?.toString(),
    );
  }
}

class CustomerSupportMessage {
  const CustomerSupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.message,
    required this.createdAt,
    this.senderId,
    this.isInternalNote = false,
  });

  final String id;
  final String ticketId;
  final String senderType;
  final String? senderId;
  final String message;
  final DateTime createdAt;
  final bool isInternalNote;

  bool get isAdmin => senderType == 'admin';
  bool get isUser => senderType == 'user';

  factory CustomerSupportMessage.fromMap(Map<String, dynamic> map) {
    return CustomerSupportMessage(
      id: map['id']?.toString() ?? '',
      ticketId: map['ticket_id']?.toString() ?? '',
      senderType: map['sender_type']?.toString() ?? 'user',
      senderId: map['sender_id']?.toString(),
      message: map['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isInternalNote: map['is_internal_note'] == true,
    );
  }
}

class CustomerSupportAttachment {
  const CustomerSupportAttachment({
    required this.id,
    required this.ticketId,
    required this.fileUrl,
    required this.fileName,
    this.messageId,
    this.fileType,
    this.fileSize,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String? messageId;
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final DateTime createdAt;

  factory CustomerSupportAttachment.fromMap(Map<String, dynamic> map) {
    return CustomerSupportAttachment(
      id: map['id']?.toString() ?? '',
      ticketId: map['ticket_id']?.toString() ?? '',
      messageId: map['message_id']?.toString(),
      fileUrl: map['file_url']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? 'dosya',
      fileType: map['file_type']?.toString(),
      fileSize: map['file_size'] is num
          ? (map['file_size'] as num).toInt()
          : int.tryParse(map['file_size']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class CustomerSupportTicketDetail {
  const CustomerSupportTicketDetail({
    required this.ticket,
    required this.messages,
    required this.attachments,
  });

  final CustomerSupportTicket ticket;
  final List<CustomerSupportMessage> messages;
  final List<CustomerSupportAttachment> attachments;
}

class CreateCustomerSupportTicketInput {
  const CreateCustomerSupportTicketInput({
    required this.category,
    this.subcategory,
    required this.title,
    required this.message,
    required this.priority,
    required this.contactPreference,
    this.relatedReference,
    this.userEmail,
    this.userPhone,
  });

  final String category;
  final String? subcategory;
  final String title;
  final String message;
  final CustomerSupportPriority priority;
  final CustomerSupportContactPreference contactPreference;
  final String? relatedReference;
  final String? userEmail;
  final String? userPhone;

  String? validate() {
    if (category.trim().isEmpty) return 'Kategori seçin.';
    if (title.trim().isEmpty) return 'Başlık zorunludur.';
    if (message.trim().length < 3) {
      return 'Mesaj çok kısa.';
    }
    return null;
  }
}
