class RecommendationsFeed {
  const RecommendationsFeed({
    required this.items,
  });

  final List<RecommendationItem> items;

  factory RecommendationsFeed.fromJson(Map<String, dynamic> json) {
    final items = _mapList(json['items']);
    return RecommendationsFeed(
      items: items.map(RecommendationItem.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(growable: false),
    };
  }
}

class RecommendationItem {
  const RecommendationItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.synopsis,
    required this.genres,
    required this.isPremium,
    required this.contentRating,
    required this.isFeatured,
    required this.isDubbed,
    required this.views,
    required this.posterUrl,
    required this.featuredImageUrl,
    required this.logoUrl,
    required this.watchSlug,
    required this.watchEpisodeNumber,
  });

  final int id;
  final String slug;
  final String title;
  final String synopsis;
  final List<String> genres;
  final bool isPremium;
  final String contentRating;
  final bool isFeatured;
  final bool isDubbed;
  final int views;
  final String posterUrl;
  final String featuredImageUrl;
  final String logoUrl;
  final String watchSlug;
  final int watchEpisodeNumber;

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    final watch = (json['watch'] is Map) ? (json['watch'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    return RecommendationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      synopsis: (json['synopsis'] as String?) ?? '',
      genres: _stringList(json['genres']),
      isPremium: json['is_premium'] == true,
      contentRating: (json['content_rating'] as String?) ?? 'all',
      isFeatured: json['is_featured'] == true,
      isDubbed: json['is_dubbed'] == true,
      views: (json['initial_views'] as num?)?.toInt() ?? 0,
      posterUrl: (json['poster_url'] as String?) ?? '',
      featuredImageUrl: (json['featured_image_url'] as String?) ?? '',
      logoUrl: (json['logo_url'] as String?) ?? '',
      watchSlug: (watch['slug'] as String?) ?? ((json['slug'] as String?) ?? ''),
      watchEpisodeNumber: (watch['episode_number'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'synopsis': synopsis,
      'genres': genres,
      'is_premium': isPremium,
      'content_rating': contentRating,
      'is_featured': isFeatured,
      'is_dubbed': isDubbed,
      'initial_views': views,
      'poster_url': posterUrl,
      'featured_image_url': featuredImageUrl,
      'logo_url': logoUrl,
      'watch': {
        'slug': watchSlug,
        'episode_number': watchEpisodeNumber,
      },
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

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}

