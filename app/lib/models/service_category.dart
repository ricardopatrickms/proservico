class ServiceCategory {
  final String id;
  final String name;
  final String? parentId;
  final bool active;
  final List<ServiceCategory> children;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.active = true,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;

  /// Itens escolhíveis no select: filhos, ou a própria categoria se não tiver filhos.
  List<ServiceCategory> get selectable {
    if (children.isEmpty) return [this];
    return children;
  }

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return ServiceCategory(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      active: json['active'] == true || json['active'] == 1,
      children: rawChildren is List
          ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map(ServiceCategory.fromJson)
              .toList()
          : const [],
    );
  }
}
