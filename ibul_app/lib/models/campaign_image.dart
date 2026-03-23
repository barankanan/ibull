
class CampaignImage {
  final int? id;
  final String imagePath;
  final String? mobileImagePath;
  final String? title;
  final String? altText;
  final String? linkUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CampaignImage({
    this.id,
    required this.imagePath,
    this.mobileImagePath,
    this.title,
    this.altText,
    this.linkUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CampaignImage.fromJson(Map<String, dynamic> json) {
    return CampaignImage(
      id: json['id'],
      imagePath: json['image_path'] ?? '',
      mobileImagePath: json['mobile_image_path'],
      title: json['title'],
      altText: json['alt_text'],
      linkUrl: json['link_url'],
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_path': imagePath,
      'mobile_image_path': mobileImagePath,
      'title': title,
      'alt_text': altText,
      'link_url': linkUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CampaignImage copyWith({
    int? id,
    String? imagePath,
    String? mobileImagePath,
    String? title,
    String? altText,
    String? linkUrl,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CampaignImage(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      mobileImagePath: mobileImagePath ?? this.mobileImagePath,
      title: title ?? this.title,
      altText: altText ?? this.altText,
      linkUrl: linkUrl ?? this.linkUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
