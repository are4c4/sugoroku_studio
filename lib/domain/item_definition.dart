enum ItemUseActionType { changePoints }

class ItemDefinition {
  const ItemDefinition({
    required this.name,
    required this.actionType,
    this.description = '',
    this.parameters = const <String, dynamic>{},
  });

  final String name;
  final String description;
  final ItemUseActionType actionType;
  final Map<String, dynamic> parameters;

  int get pointsDelta {
    final raw = parameters['points'];
    return raw is num ? raw.toInt() : 0;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'actionType': actionType.name,
        'parameters': parameters,
      };

  factory ItemDefinition.fromJson(Map<String, dynamic> json) {
    final rawActionType = json['actionType'] as String?;
    final actionType = ItemUseActionType.values.where(
      (item) => item.name == rawActionType,
    );
    return ItemDefinition(
      name: (json['name'] as String? ?? '').trim(),
      description: json['description'] as String? ?? '',
      actionType: actionType.isEmpty
          ? ItemUseActionType.changePoints
          : actionType.first,
      parameters: Map<String, dynamic>.from(
        json['parameters'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }
}
