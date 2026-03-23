import 'image.dart';

class TripClaim {
  final List<Image> images;
  final String description;
  final String? currentLocation;

  TripClaim({
    required this.images,
    required this.description,
    this.currentLocation,
  });

  // Convert TripClaim to JSON
  Map<String, dynamic> toJson() {
    return {
      'images': images.map((img) => img.toJson()).toList(),
      'description': description,
      'currentLocation': currentLocation,
    };
  }

  // Create TripClaim from JSON
  factory TripClaim.fromJson(Map<String, dynamic> json) {
    return TripClaim(
      images: (json['images'] as List<dynamic>?)
              ?.map((img) => Image.fromJson(img as Map<String, dynamic>))
              .toList() ??
          [],
      description: json['description'] as String,
      currentLocation: json['currentLocation'] as String?,
    );
  }

  // Create a copy of TripClaim with modified fields
  TripClaim copyWith({
    List<Image>? images,
    String? description,
    String? currentLocation,
  }) {
    return TripClaim(
      images: images ?? this.images,
      description: description ?? this.description,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }

  @override
  String toString() => 'TripClaim(images: ${images.length}, description: $description, currentLocation: $currentLocation)';
}
