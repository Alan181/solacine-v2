class SearchSeries {
  const SearchSeries({
    required this.id,
    required this.slug,
    required this.title,
    required this.posterUrl,
    required this.synopsis,
    required this.genre,
    required this.isPremium,
    required this.isFeatured,
    required this.isDubbed,
    required this.views,
    required this.searchCount,
  });

  final int id;
  final String slug;
  final String title;
  final String posterUrl;
  final String synopsis;
  final String genre;
  final bool isPremium;
  final bool isFeatured;
  final bool isDubbed;
  final int views;
  final int searchCount;

  factory SearchSeries.fromJson(Map<String, dynamic> json) {
    return SearchSeries(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      posterUrl: (json['poster_url'] as String?) ?? '',
      synopsis: (json['synopsis'] as String?) ?? '',
      genre: (json['genre'] as String?) ?? '',
      isPremium: json['is_premium'] == true,
      isFeatured: json['is_featured'] == true,
      isDubbed: json['is_dubbed'] == true,
      views: (json['initial_views'] as num?)?.toInt() ?? 0,
      searchCount: (json['search_count'] as num?)?.toInt() ?? 0,
    );
  }
}

