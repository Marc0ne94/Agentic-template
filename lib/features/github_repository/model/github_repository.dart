/// Public repository information displayed by the GitHub example.
class GithubRepository {
  const GithubRepository({
    required this.fullName,
    required this.description,
    required this.stars,
    required this.pushedAt,
  });

  final String fullName;
  final String? description;
  final int stars;
  final DateTime? pushedAt;

  factory GithubRepository.fromJson(Map<String, dynamic> json) {
    final fullName = json['full_name'];
    final description = json['description'];
    final stars = json['stargazers_count'];
    final pushedAtValue = json['pushed_at'];

    if (fullName is! String ||
        fullName.trim().isEmpty ||
        stars is! int ||
        stars < 0 ||
        (description != null && description is! String) ||
        (pushedAtValue != null && pushedAtValue is! String)) {
      throw const FormatException('Invalid repository metadata.');
    }

    final pushedAt = pushedAtValue is String
        ? DateTime.tryParse(pushedAtValue)
        : null;
    if (pushedAtValue != null && pushedAt == null) {
      throw const FormatException('Invalid repository timestamp.');
    }

    return GithubRepository(
      fullName: fullName,
      description: description as String?,
      stars: stars,
      pushedAt: pushedAt,
    );
  }
}
