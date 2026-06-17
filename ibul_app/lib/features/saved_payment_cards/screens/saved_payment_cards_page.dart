import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/account_sidebar.dart';
import '../../../widgets/web_header.dart';
import '../../../widgets/web_sticky_footer_scroll_view.dart';
import '../models/saved_payment_card_models.dart';
import '../services/saved_payment_cards_service.dart';
import '../widgets/add_saved_card_sheet.dart';
import '../widgets/saved_payment_card_tile.dart';
import '../widgets/saved_payment_cards_empty_state.dart';
import '../widgets/saved_payment_security_banner.dart';

class SavedPaymentCardsPage extends StatefulWidget {
  const SavedPaymentCardsPage({super.key});

  @override
  State<SavedPaymentCardsPage> createState() => _SavedPaymentCardsPageState();
}

class _SavedPaymentCardsPageState extends State<SavedPaymentCardsPage> {
  final _service = SavedPaymentCardsService.instance;
  late Future<List<SavedPaymentCard>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _cardsFuture = _service.getMyCards();
  }

  Future<void> _openAddCard() async {
    final added = await showAddSavedCardSheet(context);
    if (added == true && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kart kaydedildi.')),
      );
    }
  }

  Future<void> _setDefault(SavedPaymentCard card) async {
    try {
      await _service.setDefaultCard(card.id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varsayılan kart güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteCard(SavedPaymentCard card) async {
    await showDeleteSavedCardDialog(
      context,
      onConfirm: () async {
        try {
          await _service.deleteCard(card.id);
          if (!mounted) return;
          setState(_reload);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kart silindi.')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.sizeOf(context).width >= 800;
    if (isWeb) return _buildWeb();
    return _buildMobile();
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Kartlarım'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCard,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Kart Ekle'),
      ),
      body: _buildBody(compact: true),
    );
  }

  Widget _buildWeb() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (_) {}),
          Expanded(
            child: WebStickyFooterScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: AccountSidebar(
                            activePage: 'Kayıtlı Kartlarım',
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(child: _buildBody(compact: false)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({required bool compact}) {
    return FutureBuilder<List<SavedPaymentCard>>(
      future: _cardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }

        final cards = snapshot.data ?? const <SavedPaymentCard>[];
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: compact ? double.infinity : 1000,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kartlarım',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Ödeme sırasında kullanacağın kartları güvenli şekilde yönet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _openAddCard,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Kart Ekle'),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Ödeme sırasında kullanacağın kartları güvenli şekilde yönet.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 20),
                const SavedPaymentSecurityBanner(),
                const SizedBox(height: 24),
                if (cards.isEmpty)
                  SavedPaymentCardsEmptyState(onAddCard: _openAddCard)
                else
                  _buildCardGrid(cards, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardGrid(List<SavedPaymentCard> cards, {required bool compact}) {
    if (compact) {
      return Column(
        children: [
          for (final card in cards) ...[
            SavedPaymentCardTile(
              card: card,
              compact: true,
              onSetDefault: () => _setDefault(card),
              onDelete: () => _deleteCard(card),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 72),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.65,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            return SavedPaymentCardTile(
              card: card,
              onSetDefault: () => _setDefault(card),
              onDelete: () => _deleteCard(card),
            );
          },
        );
      },
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => setState(_reload), child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
