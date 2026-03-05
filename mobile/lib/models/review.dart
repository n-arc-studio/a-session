class Review {
  const Review({
    required this.id,
    required this.songId,
    required this.reviewerId,
    required this.rating,
    this.comment,
  });

  final String id;
  final String songId;
  final String reviewerId;
  final int rating;
  final String? comment;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      songId: json['song_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
    );
  }
}
