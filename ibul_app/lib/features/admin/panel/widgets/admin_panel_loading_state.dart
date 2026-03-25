import 'package:flutter/material.dart';

import '../../../../widgets/skeleton_loading.dart';

class AdminPanelLoadingState extends StatelessWidget {
  const AdminPanelLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 960;
          if (isCompact) {
            return const _AdminPanelLoadingMobileLayout();
          }

          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 280, child: _AdminPanelSidebarSkeleton()),
              Expanded(child: _AdminPanelContentSkeleton()),
            ],
          );
        },
      ),
    );
  }
}

class _AdminPanelLoadingMobileLayout extends StatelessWidget {
  const _AdminPanelLoadingMobileLayout();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: const [
        SkeletonLoading(width: 180, height: 28, borderRadius: 12),
        SizedBox(height: 18),
        SkeletonLoading(width: double.infinity, height: 68, borderRadius: 20),
        SizedBox(height: 14),
        SkeletonLoading(width: double.infinity, height: 56, borderRadius: 18),
        SizedBox(height: 18),
        _AdminPanelMainCardSkeleton(),
      ],
    );
  }
}

class _AdminPanelSidebarSkeleton extends StatelessWidget {
  const _AdminPanelSidebarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  SkeletonLoading(width: 36, height: 36, borderRadius: 10),
                  SizedBox(width: 12),
                  SkeletonLoading(width: 142, height: 22, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 20),
              const SkeletonLoading(
                width: double.infinity,
                height: 72,
                borderRadius: 18,
              ),
              const SizedBox(height: 24),
              ...List.generate(
                6,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SkeletonLoading(
                    width: double.infinity,
                    height: 48,
                    borderRadius: 14,
                  ),
                ),
              ),
              const Spacer(),
              const SkeletonLoading(
                width: double.infinity,
                height: 64,
                borderRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPanelContentSkeleton extends StatelessWidget {
  const _AdminPanelContentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _AdminPanelTopbarSkeleton(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: _AdminPanelMainCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _AdminPanelTopbarSkeleton extends StatelessWidget {
  const _AdminPanelTopbarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Row(
        children: const [
          SkeletonLoading(width: 192, height: 24, borderRadius: 10),
          Spacer(),
          SkeletonLoading(width: 220, height: 42, borderRadius: 14),
          SizedBox(width: 12),
          SkeletonLoading(width: 42, height: 42, borderRadius: 14),
        ],
      ),
    );
  }
}

class _AdminPanelMainCardSkeleton extends StatelessWidget {
  const _AdminPanelMainCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoading(width: 180, height: 24, borderRadius: 10),
          const SizedBox(height: 8),
          const SkeletonLoading(width: 260, height: 14, borderRadius: 7),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(
                  isWide ? 4 : 2,
                  (index) => SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 48) / 4
                        : (constraints.maxWidth - 16) / 2,
                    child: const SkeletonLoading(
                      width: double.infinity,
                      height: 110,
                      borderRadius: 20,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          const SkeletonLoading(
            width: double.infinity,
            height: 320,
            borderRadius: 24,
          ),
          const SizedBox(height: 18),
          const SkeletonLoading(
            width: double.infinity,
            height: 220,
            borderRadius: 24,
          ),
        ],
      ),
    );
  }
}
