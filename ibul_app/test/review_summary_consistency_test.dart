import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/review_repository.dart';

void main() {
  test('ReviewSummary count matches reviews list length', () {
    final reviews = [
      {
        'userName': 'Ali',
        'rating': 5,
        'comment': 'Harika',
        'createdAt': '2026-06-01T10:00:00.000Z',
      },
      {
        'userName': 'Ayşe',
        'rating': 4,
        'comment': '',
        'createdAt': '2026-06-02T10:00:00.000Z',
      },
    ];

    final summary = ReviewSummary.fromReviews(reviews);

    expect(summary.reviewCount, 2);
    expect(summary.reviews.length, 2);
    expect(summary.averageRating, 4.5);
  });

  test('ReviewSummary uses fallback only when reviews empty', () {
    final summary = ReviewSummary.fromReviews(
      const [],
      fallbackRating: 4.2,
      fallbackCount: 3,
    );

    expect(summary.reviewCount, 3);
    expect(summary.reviews, isEmpty);
    expect(summary.averageRating, 4.2);
  });
}
