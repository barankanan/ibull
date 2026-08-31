import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../data/support_category_catalog.dart';
import '../models/customer_support_models.dart';
import '../services/customer_support_service.dart';

class CustomerSupportCreateTicketPage extends StatefulWidget {
  const CustomerSupportCreateTicketPage({
    super.key,
    this.initialCategory,
    this.initialSubcategory,
  });

  final SupportCategoryOption? initialCategory;
  final String? initialSubcategory;

  @override
  State<CustomerSupportCreateTicketPage> createState() =>
      _CustomerSupportCreateTicketPageState();
}

class _CustomerSupportCreateTicketPageState
    extends State<CustomerSupportCreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _referenceController = TextEditingController();

  late SupportCategoryOption? _selectedCategory;
  String? _selectedSubcategory;
  CustomerSupportPriority _priority = CustomerSupportPriority.normal;
  CustomerSupportContactPreference _contactPreference =
      CustomerSupportContactPreference.inApp;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedSubcategory = widget.initialSubcategory;
    if (_selectedSubcategory != null) {
      _titleController.text = _selectedSubcategory!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori ve alt başlık seçin.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final ticket = await CustomerSupportService.instance.createTicket(
        CreateCustomerSupportTicketInput(
          category: _selectedCategory!.id,
          subcategory: _selectedSubcategory!,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          priority: _priority,
          contactPreference: _contactPreference,
          relatedReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          userEmail: user?.email,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Talep oluşturuldu'),
          content: Text(
            'Talep numaranız: #${ticket.displayTicketNumber}\n'
            'Durum: İncelemede',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AppState, bool>((s) => s.isLoggedIn);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destek Talebi Oluştur'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
      ),
      body: loggedIn
          ? Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<SupportCategoryOption>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori *'),
                    items: supportCategoryCatalog
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _selectedSubcategory = null;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Kategori seçin' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubcategory,
                    decoration: const InputDecoration(labelText: 'Alt başlık *'),
                    items: (_selectedCategory?.subcategories ?? const [])
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubcategory = value;
                        if (_titleController.text.trim().isEmpty && value != null) {
                          _titleController.text = value;
                        }
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Alt başlık seçin' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Başlık *'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Başlık zorunlu' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Mesaj / açıklama *',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'Mesaj zorunlu';
                      if (text.length < 10) return 'En az 10 karakter yazın';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Sipariş no / mağaza / ürün (opsiyonel)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CustomerSupportContactPreference>(
                    initialValue: _contactPreference,
                    decoration: const InputDecoration(
                      labelText: 'İletişim tercihi',
                    ),
                    items: CustomerSupportContactPreference.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _contactPreference = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CustomerSupportPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Aciliyet'),
                    items: CustomerSupportPriority.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _priority = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Talep Oluştur'),
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: Text('Talep oluşturmak için giriş yapın.')),
    );
  }
}
