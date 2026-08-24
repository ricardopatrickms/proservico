class Bank {
  final int? code;
  final String name;
  final String fullName;
  final String ispb;

  const Bank({
    required this.code,
    required this.name,
    required this.fullName,
    required this.ispb,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    final codeRaw = json['code'];
    return Bank(
      code: codeRaw is int ? codeRaw : int.tryParse(codeRaw?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? '',
      ispb: json['ispb']?.toString() ?? '',
    );
  }

  String get label {
    final title = fullName.trim().isNotEmpty ? fullName.trim() : name.trim();
    if (code == null) return title;
    return '${code.toString().padLeft(3, '0')} - $title';
  }

  String get value => label;
}
