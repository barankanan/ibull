import 'package:flutter/material.dart';

import 'customer_support_chat_page.dart';

/// Mevcut ticket detayı artık sohbet arayüzü üzerinden açılır.
class CustomerSupportTicketDetailPage extends StatelessWidget {
  const CustomerSupportTicketDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context) {
    return CustomerSupportChatPage(ticketId: ticketId);
  }
}
