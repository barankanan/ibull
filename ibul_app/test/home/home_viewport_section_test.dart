import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/home/home_viewport_section.dart';

void main() {
  testWidgets('section outside viewport does not trigger loadLibrary', (tester) async {
    int loadCalls = 0;
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 2000), // Pushes section far out of viewport
              HomeViewportSection(
                placeholderHeight: 300,
                loadLibrary: () async {
                  loadCalls++;
                },
                builder: () => const Text('Loaded Section'),
              ),
            ],
          ),
        ),
      ),
    );

    // Initial pump & postFrameCallback
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(loadCalls, 0);
    expect(find.text('Loaded Section'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('scrolling into proximity triggers loadLibrary exactly once and renders child', (tester) async {
    int loadCalls = 0;
    final completer = Completer<void>();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 1200),
              HomeViewportSection(
                placeholderHeight: 300,
                loadLibrary: () {
                  loadCalls++;
                  return completer.future;
                },
                builder: () => const Text('Loaded Section'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(loadCalls, 0);

    // Scroll down to bring section near/into viewport
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();

    expect(loadCalls, 1);
    expect(find.text('Loaded Section'), findsNothing);

    // Complete the library load
    completer.complete();
    await tester.pump();

    expect(find.text('Loaded Section'), findsOneWidget);
    expect(loadCalls, 1);

    // Rebuild shouldn't call loadLibrary again
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 1200),
              HomeViewportSection(
                placeholderHeight: 300,
                loadLibrary: () async {
                  loadCalls++;
                },
                builder: () => const Text('Loaded Section'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(loadCalls, 1);
    expect(find.text('Loaded Section'), findsOneWidget);
  });

  testWidgets('disposed section before load completes does not crash on completion', (tester) async {
    final completer = Completer<void>();
    int loadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              // Intersects immediately
              HomeViewportSection(
                placeholderHeight: 300,
                loadLibrary: () {
                  loadCalls++;
                  return completer.future;
                },
                builder: () => const Text('Loaded Section'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    expect(loadCalls, 1);

    // Remove the section from the tree before completion
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Replaced'),
        ),
      ),
    );
    await tester.pump();

    // Now complete the future after widget is unmounted
    completer.complete();
    await tester.pump();

    // No exception thrown
    expect(find.text('Replaced'), findsOneWidget);
  });
}
