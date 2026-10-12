class StudyMaterial {
  final int? id;
  final String? title;
  final String originalFilename;
  final String status;
  final int sizeBytes;
  final String? mimeType;
  final String? processingError;
  final int? disciplineId;
  final int? topicId;

  const StudyMaterial({
    this.id,
    this.title,
    required this.originalFilename,
    required this.status,
    required this.sizeBytes,
    this.mimeType,
    this.processingError,
    this.disciplineId,
    this.topicId,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) => StudyMaterial(
        id: json['id'] as int?,
        title: json['title'] as String?,
        originalFilename: json['original_filename'] as String? ?? 'Material',
        status: json['status'] as String? ?? 'uploaded',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        mimeType: json['mime_type'] as String?,
        processingError: json['processing_error'] as String?,
        disciplineId:
            (json['discipline'] as Map<String, dynamic>?)?['id'] as int?,
        topicId: (json['topic'] as Map<String, dynamic>?)?['id'] as int?,
      );
}

String formatMaterialSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
