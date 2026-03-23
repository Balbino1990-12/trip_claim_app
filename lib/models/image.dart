class Image {
  final String id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime uploadDate;
  final String? description;

  Image({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.uploadDate,
    this.description,
  });

  // Convert Image to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'uploadDate': uploadDate.toIso8601String(),
      'description': description,
    };
  }

  // Create Image from JSON
  factory Image.fromJson(Map<String, dynamic> json) {
    return Image(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      fileSize: json['fileSize'] as int,
      mimeType: json['mimeType'] as String,
      uploadDate: DateTime.parse(json['uploadDate'] as String),
      description: json['description'] as String?,
    );
  }

  // Create a copy of Image with modified fields
  Image copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    DateTime? uploadDate,
    String? description,
  }) {
    return Image(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      uploadDate: uploadDate ?? this.uploadDate,
      description: description ?? this.description,
    );
  }

  @override
  String toString() => 'Image(id: $id, fileName: $fileName, fileSize: $fileSize, uploadDate: $uploadDate)';
}
