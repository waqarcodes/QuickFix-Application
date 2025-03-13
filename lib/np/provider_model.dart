class Provider {
  String id;
  String name;
  List<String> services;
  String experience;
  double averageRating;
  int reviewCount;

  Provider({
    required this.id,
    required this.name,
    required this.services,
    required this.experience,
    required this.averageRating,
    required this.reviewCount,
  });

  factory Provider.fromMap(Map<String, dynamic> data, String id) {
    return Provider(
      id: id,
      name: data['name'],
      services: List<String>.from(data['services']),
      experience: data['experience'],
      averageRating: data['averageRating'],
      reviewCount: data['reviewCount'],
    );
  }
}
