import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class GqlFormGenerator extends Generator {
  final BuilderOptions builderOptions;

  GqlFormGenerator(this.builderOptions);

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    if (getInputClass(library) == null) {
      return "// Has no list";
    } else {
      var buffer = StringBuffer();

      String sourceCode = template
          .replaceAll('{rootNode}', getRootNode(library).displayName)
          .replaceAll('{fields}', generateFields(library))
          .replaceAll('{fieldsList}', generateFields(library, generate: "fieldsList"))
          .replaceAll(
              '{inputParameter}', generateFields(library, generate: "param"))
          .replaceAll('{inputParameterFields}',
              generateFields(library, generate: "paramField"))
          .replaceAll('{buttons}',
              "// Button(child: Text('submit'), onPressed: () {}),")
          .replaceAll(
              '{argsDeclaration}',
              getArgumentsClass(library) == null
                  ? ''
                  : 'final ${getClassName(library)}Arguments args;')
          .replaceAll('{argsParam}',
              getArgumentsClass(library) == null ? '' : ', required this.args')
          .replaceAll('{args}',
              getArgumentsClass(library) == null ? '' : 'widget.args')
          .replaceAll('{className}', getClassName(library));

      buffer.writeln(imports(library));
      buffer.writeln(sourceCode);
      return buffer.toString();
    }
  }

  String clear_argumetns(String sourceCode) {
    sourceCode = sourceCode.replaceAll('this.loadingItems.add(args);', '');
    sourceCode = sourceCode.replaceAll('variables: event.args', '');
    sourceCode = sourceCode.replaceAll('variables: args', '');
    sourceCode = sourceCode.replaceAll('final TemplateArguments? args;', '');
    sourceCode =
        sourceCode.replaceAll('final TemplateArguments? withArgs;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments args;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments withArgs;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments? args;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments? withArgs;', '');
    sourceCode = sourceCode.replaceAll('List<dynamic> loadingItems = [];', '');
    sourceCode =
        sourceCode.replaceAll('this.loadingItems.add(event.args);', '');
    sourceCode = sourceCode.replaceAll('loadingItems: this.loadingItems', '');
    sourceCode = sourceCode.replaceAll('List<dynamic>? loadingItems;', '');
    sourceCode =
        sourceCode.replaceAll('TemplateLoadingState({this.loadingItems});', '');

    sourceCode = sourceCode.replaceAll(', this.withArgs', '');
    sourceCode = sourceCode.replaceAll(', this.args', '');
    sourceCode = sourceCode.replaceAll('this.withArgs,', '');
    sourceCode = sourceCode.replaceAll('this.args,', '');
    sourceCode = sourceCode.replaceAll('event.withArgs', '');
    sourceCode = sourceCode.replaceAll('event.args', '');
    sourceCode = sourceCode.replaceAll('withArgs', '');
    sourceCode = sourceCode.replaceAll('args', '');
    sourceCode = sourceCode.replaceAll(', args', '');
    return sourceCode;
  }

  ClassElement getClass(LibraryReader library) {
    return library.classes.firstWhere((e) =>
        e.displayName.contains('MutationInput') ||
        e.displayName.contains('\$Mutation'));
  }

  FieldElement getRootNode(library) => getClass(library).fields.firstWhere((e) {
        return e.type.toString().contains("Node") ||
            e.type.toString().contains("Payload") ||
            e.type.toString().contains("Mutation");
      });

  FieldElement? getArgumentsClass(LibraryReader library) {
    final argumentClass = library.classes
        .firstWhere((e) =>
            e.displayName == getClass(library).displayName.replaceAll("\$", ""))
        .fields
        .where((e) => e.type.toString().endsWith("Arguments"));
    return (argumentClass.isEmpty) ? null : argumentClass.first;
  }

  ClassElement? getInputClass(LibraryReader library) {
    final argumentClass = library.classes
        .where((e) => e.displayName.toString().endsWith("MutationInput"));
    return (argumentClass.isEmpty) ? null : argumentClass.first;
  }

  bool hasEdges(LibraryReader library) {
    final argumentClass = getClass(library)
        .fields
        .where((e) => e.toString().contains("Connection"));
    return argumentClass.isNotEmpty;
  }

  String getClassName(LibraryReader library) {
    return getClass(library)
        .displayName
        .replaceAll('\$Query', '')
        .replaceAll('\$Mutation', '');
  }

  String imports(
    LibraryReader library,
  ) {
    var imports = StringBuffer();

    imports.write("""
    import 'package:flutter/material.dart';
    import 'package:form_builder_validators/form_builder_validators.dart';
    import 'package:flutter_form_builder/flutter_form_builder.dart';
    """);

    imports.write(
        'import \'package:${builderOptions.config['graphql_client']['import'].toString()}\';');
    imports.write(
        'import \'package:${library.element.source.toString().substring(1).replaceFirst("lib/", "")}\';');
    imports.write(
        'import \'package:${library.element.source.toString().substring(1).replaceFirst("lib/", "").replaceFirst(".dart", ".bloc.dart")}\';');
    // updateImports(buildStep, imports.toString());
    return imports.toString();
  }

  String hydratedEditor(LibraryReader library, String sourceCode) {
    try {
      FieldElement nodeField = getClass(library).fields.firstWhere((e) {
        return e.type.toString().contains("Node") ||
            e.type.toString().contains("Payload") ||
            e.type.toString().contains("Mutation");
      });

      if (isQuery(library)) {
        sourceCode = sourceCode
            .replaceAll('Bloc<', 'HydratedBloc<')
            .replaceAll('// fromJsonPlaceholder', fromJsonTemplate)
            .replaceAll('// toJsonPlaceholder', toJsonTemplate);
        if (getArgumentsClass(library) == null) {
          sourceCode = sourceCode.replaceAll(
              'return TemplateLoadedState(TemplateNodeConnection.fromJson(json), null);',
              'return TemplateLoadedState(TemplateNodeConnection.fromJson(json));');
        }
      }
      sourceCode = sourceCode
          .replaceAll('#rootNode', nodeField.displayName)
          .replaceAll('TemplateNodeConnection',
              nodeField.type.toString().replaceAll("?", ""));
      return sourceCode;
    } catch (e) {
      print(e);
      sourceCode = sourceCode.replaceAll('#rootNode', 'rootNode');
      return sourceCode;
    }
  }

  String generateFields(LibraryReader library, {String generate = "fields"}) {
    StringBuffer fields = StringBuffer();
    List<String> skipFields = ["props", "clientMutationId"];
    int i = 0;
    for (var field in getInputClass(library)!.fields) {
      if (skipFields.contains(field.displayName)) continue;
      switch (generate) {
        case 'fields':
          fields.writeln(generateField(field));
          break;
        case 'fieldsList':
          fields.writeln("widget.${field.displayName},");
          break;
        case 'param':
          String arg =
              "this.${field.displayName} = const {className}Field(label: '${field.displayName}', order: ${i++},name: '${field.displayName}', type: ${formFieldType(field)}, hidden: ${field.displayName == 'id' ? 'true' : 'false'}, isRequired: ${field.type.toString().endsWith("?") ? 'false' : 'true'}),";
          fields.writeln(arg);
          break;
        case 'paramField':
          fields.writeln("final {className}Field ${field.displayName};");
          break;
      }
    }
    return fields.toString();
  }

  String generateField(FieldElement field) {
    String type = field.type.toString();

    return """
      _field(context, '${field.displayName}', widget.${field.displayName}, widget.${field.displayName}.type, ${type.endsWith("?") ? "true" : "false"}),
      SizedBox(height: widget.verticalGap),
      """;
  }

  bool hasPageInfo(LibraryReader library, FieldElement nodeField) {
    return library.classes
        .firstWhere((e) =>
            e.displayName == nodeField.type.toString().replaceAll('?', ''))
        .fields
        .where((e) => e.displayName == "pageInfo")
        .isNotEmpty;
  }

  Future<void> updateImports(buildStep, imports) async {
    var file = await buildStep.readAsString(buildStep.inputId);
    final fileLines = file.split('\n');
    fileLines.insert(3, imports);
    try {
      File outputFile = File(buildStep.inputId.path);
      outputFile.writeAsStringSync(fileLines.join('\n'));
    } catch (e) {
      print(e);
    }
  }

  late String template = """ 
 
  enum {className}FieldType { TEXT, NUMBER, DROPDOWN, CHECKBOX, CHIPS, DATETIME}
  
class {className}Field {
  const {className}Field({
    required this.label, 
    this.hidden = true, 
    this.isRequired = false, 
    required this.name, 
    required this.type,
    this.labelWidget = const Text(''),
    this.value,
    this.validators = const [], 
    this.items = const [], 
    required this.order,
    this.formBuilderField,
    this.decoration});

  final String label;
  final String name;
  final bool isRequired;
  final bool hidden;
  final value;
  final InputDecoration? decoration;
  final List<FormFieldValidator<dynamic>> validators;
  final List<DropdownMenuItem> items;
  final {className}FieldType type;
  final Widget labelWidget;
  final order;
  final formBuilderField;
}

class {className}Form extends StatefulWidget {
  const {className}Form({super.key, 
  this.decoration=const InputDecoration(),
   this.extraFields = const [],
  this.title = const Padding(padding: EdgeInsets.zero,),
  
  this.verticalGap=4.0,
    this.buildSubmit, {inputParameter}});
  
  final InputDecoration decoration;
  final Widget Function(BuildContext, FormBuilderState?)? buildSubmit;
  final Widget title;
  final double verticalGap;
  final List<{className}Field> extraFields;
  {inputParameterFields}
  
  @override
  State<{className}Form> createState() => _{className}FormState();
}

class _{className}FormState extends State<{className}Form> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      child:   Column(
        children: [
          widget.title,
          ..._fieldsList().map((e) => _field(context, e)),
           Builder(
              builder: widget.buildSubmit != null
                  ? (context) =>
                      widget.buildSubmit?.call(context, _formKey.currentState) ?? Container()
                  : (context) => Container())
        ],
      ),
    );
  }
  
  List<dynamic> _fieldsList() {
    final fields = <{className}Field>[
      {fieldsList}
      ...widget.extraFields
    ];
    fields.sort((a, b) => a.order.compareTo(b.order));
    return fields;
  }
  
   Widget _field(BuildContext context, {className}Field formField) {
   Widget fieldWidget = Container();
   
   if (formField.formBuilderField != null) {
      return formField.formBuilderField;
   }
    switch (formField.type) {
      case {className}FieldType.TEXT:
        fieldWidget =  FormBuilderTextField(
        name: formField.name,
        initialValue: formField.value,
        decoration: (formField.decoration ?? widget.decoration).copyWith(labelText: formField.label),
        validator: FormBuilderValidators.compose(<FormFieldValidator<dynamic>>[
         if(formField.isRequired) FormBuilderValidators.required(context)
        ] + formField.validators),
      );
      break;
       case {className}FieldType.NUMBER:
        fieldWidget = FormBuilderTextField(
          name: formField.name,
          initialValue: formField.value,
          keyboardType: TextInputType.number,
          decoration: (formField.decoration ?? widget.decoration)
              .copyWith(labelText: formField.label),
          validator: FormBuilderValidators.compose(
              <FormFieldValidator<dynamic>>[
                if (formField.isRequired) FormBuilderValidators.required(context)
              ] +
                  formField.validators),
        );
        break;
      case {className}FieldType.DROPDOWN:
        fieldWidget =  FormBuilderDropdown<dynamic>(
          name: formField.name,
          decoration: (formField.decoration ?? widget.decoration)
              .copyWith(labelText: formField.label),
          items: formField.items,
        );
        break;
      case {className}FieldType.CHECKBOX:
        fieldWidget =  FormBuilderCheckbox(
          name: formField.name,
          title: formField.labelWidget,
          decoration: (formField.decoration ?? widget.decoration)
              .copyWith(labelText: formField.label),
        );
        break;
      case {className}FieldType.CHIPS:
        // TODO: Handle this case.
        break;
      case {className}FieldType.DATETIME:
        fieldWidget =  FormBuilderDateTimePicker(
            name: formField.name,
            decoration: (formField.decoration ?? widget.decoration)
                .copyWith(labelText: formField.label));
        break;
    }
    return fieldWidget;
  } 
}
""";

  late String fromJsonTemplate = """
  @override
  TemplateState? fromJson(Map<String, dynamic> json) {
    try {
      return TemplateLoadedState(TemplateNodeConnection.fromJson(json), null);
    } catch (_) {
      return null;
    }
  }
  """;

  late String toJsonTemplate = """
  @override
  Map<String, dynamic>? toJson(TemplateState state) {
    if (state is TemplateLoadedState) {
      return state.#rootNode.toJson();
    } else {
      return null;
    }
  }
  """;

  late String loadMoreEventTemplate = """
  class LoadMoreTemplateEvent extends TemplateEvent {
    final TemplateArguments? args;
    LoadMoreTemplateEvent(this.args);
  
    @override
    List<Object> get props => [];
  }
  """;

  late String loadMoreHandlerTemplate = """
    void _onLoadMoreTemplateEvent(event, emit){
        final state = this.state;
        if (state is TemplateLoadedState) {
          emit(TemplateLoadingState());
          dynamic args = state.withArgs?.toJson();
          // coursorUpdatePlaceholder
         
          {load}(TemplateQuery(variables: TemplateArguments.fromJson(args)))
              .then((response) => (response.errors == null)
                  ? #rootNodeLoadedMore(response.data?.#rootNode, state)
                  : add(TemplateErrorEvent(response.errors)))
              .catchError(
                  (error) => add(TemplateExceptionEvent(error)));
        }
    }
  """;

  late String loadMoreMethodTemplate = """
  void #rootNodeLoadedMore(
      TemplateNodeConnection? #rootNode, TemplateLoadedState state) {
      #rootNode?.edges = (state.#rootNode.edges + #rootNode.edges).toSet().toList();
      this.add(TemplateLoadedEvent(#rootNode, state.withArgs));
    }
  """;

  late String coursorUpdateTemplate = """
  if (state.#rootNode.pageInfo != null) {
     args['after'] = state.#rootNode.pageInfo.endCursor;
  }
  """;

  late String keepArgsTemplate = """
  TemplateArguments args = event.args;
  final state = this.state;
  if (event.keepPreviousArgs && state is TemplateLoadedState){
     final previousArgs = state.withArgs?.toJson();
     final currentArgs = args.toJson();
     if(previousArgs != null){
        currentArgs.removeWhere((key, value) => value == null);
        previousArgs.addAll(currentArgs);
        args = TemplateArguments.fromJson(previousArgs);
     }
  }
 
 
  """;

  bool isQuery(LibraryReader library) {
    return library.classes
        .where((e) => e.displayName.contains('\$Query'))
        .isNotEmpty;
  }

  String formFieldType(FieldElement field) {
    print(field.type.toString());
    switch (field.type.toString()) {
      case 'String':
      case 'String?':
        return '{className}FieldType.TEXT';
      case 'int':
      case 'int?':
      case 'double':
      case 'double?':
        return '{className}FieldType.NUMBER';
      case 'bool':
      case 'bool?':
        return '{className}FieldType.CHECKBOX';
      case 'List<String?>?':
      case 'List<String?>':
        return '{className}FieldType.CHIPS';
      case 'DateTime?':
      case 'DateTime':
        return '{className}FieldType.DATETIME';
    }
    return '/*--->${field.type.toString()}*/ {className}FieldType.TEXT';
  }
}
