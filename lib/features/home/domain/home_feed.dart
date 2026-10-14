class HomeFeed {
  const HomeFeed({
    required this.hero,
    required this.categories,
    required this.sections,
  });

  final List<HomeSeries> hero;
  final List<HomeCategory> categories;
  final List<HomeSection> sections;

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    final hero = _mapList(json['hero']);
    final categories = _mapList(json['categories']);
    final sections = _mapList(json['sections']);

    return HomeFeed(
      hero: hero.map(HomeSeries.fromJson).toList(growable: false),
      categories: categories.map(HomeCategory.fromJson).toList(growable: false),
      sections: sections.map(HomeSection.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hero': hero.map((e) => e.toJson()).toList(growable: false),
      'categories': categories.map((e) => e.toJson()).toList(growable: false),
      'sections': sections.map((e) => e.toJson()).toList(growable: false),
    };
  }
}

class HomeSection {
  const HomeSection({
    required this.key,
    required this.title,
    required this.items,
  });

  final String key;
  final String title;
  final List<HomeSeries> items;

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final items = _mapList(json['items']);
    return HomeSection(
      key: (json['key'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      items: items.map(HomeSeries.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'items': items.map((e) => e.toJson()).toList(growable: false),
    };
  }
}

class HomeSeries {
  const HomeSeries({
    required this.id,
    required this.slug,
    required this.title,
    required this.isPremium,
    required this.isFeatured,
    required this.isDubbed,
    required this.views,
    required this.posterUrl,
    required this.featuredImageUrl,
    required this.logoUrl,
  });

  final int id;
  final String slug;
  final String title;
  final bool isPremium;
  final bool isFeatured;
  final bool isDubbed;
  final int views;
  final String posterUrl;
  final String featuredImageUrl;
  final String logoUrl;

  factory HomeSeries.fromJson(Map<String, dynamic> json) {
    return HomeSeries(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      isPremium: json['is_premium'] == true,
      isFeatured: json['is_featured'] == true,
      isDubbed: json['is_dubbed'] == true,
      views: (json['initial_views'] as num?)?.toInt() ?? (json['views'] as num?)?.toInt() ?? 0,
      posterUrl: (json['poster_url'] as String?) ?? '',
      featuredImageUrl: (json['featured_image_url'] as String?) ?? '',
      logoUrl: (json['logo_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'is_premium': isPremium,
      'is_featured': isFeatured,
      'is_dubbed': isDubbed,
      'initial_views': views,
      'poster_url': posterUrl,
      'featured_image_url': featuredImageUrl,
      'logo_url': logoUrl,
    };
  }
}

class HomeCategory {
  const HomeCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
  });

  final int id;
  final String name;
  final String slug;
  final String? imageUrl;

  factory HomeCategory.fromJson(Map<String, dynamic> json) {
    return HomeCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?)?.trim().isNotEmpty == true ? (json['image_url'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'image_url': imageUrl,
    };
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  final list = _list(value);
  return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
}

List _list(dynamic value) {
  if (value is List) return value;
  if (value is Map) return value.values.toList(growable: false);
  return const [];
}
