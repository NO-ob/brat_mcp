enum MCPropertyType { string, boolean, number }

abstract class MCPToolProperty {
  final String name;
  final String description;
  final bool required;
  final MCPropertyType type;
  final dynamic defaultValue;

  MCPToolProperty({required this.name, required this.description, this.required = false, required this.type, this.defaultValue});

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'description': description, if (defaultValue != null) 'default': defaultValue};
  }
}

class MCPToolPropertyString extends MCPToolProperty {
  MCPToolPropertyString({required super.name, required super.description, super.required, String? super.defaultValue}) : super(type: MCPropertyType.string);
}

class MCPToolPropertyBool extends MCPToolProperty {
  MCPToolPropertyBool({required super.name, required super.description, super.required, bool? super.defaultValue}) : super(type: MCPropertyType.boolean);
}

class MCPToolPropertyInt extends MCPToolProperty {
  MCPToolPropertyInt({required super.name, required super.description, super.required, int? super.defaultValue}) : super(type: MCPropertyType.number);

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> superJson = super.toJson();

    superJson["multipleOf"] = 1;

    return superJson;
  }
}
