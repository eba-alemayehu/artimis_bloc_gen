import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class GqlBlocGenerator extends Generator {
  final BuilderOptions builderOptions;

  GqlBlocGenerator(this.builderOptions);

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    var buffer = StringBuffer();
    imports(library, buildStep);

    final className = getClass(library).displayName;

    String sourceCode = template;

    if (getArgumentsClass(library) == null) {
      sourceCode = clear_argumetns(sourceCode);
    }
    sourceCode = hydratedEditor(library, sourceCode);
    sourceCode = sourceCode
        .replaceAll('TemplateQuery',
            "${getClassName(library)}${isQuery(library) ? 'Query' : 'Mutation'}")
        .replaceAll('Template', getClassName(library))
        .replaceAll('GraphQL.instance',
            builderOptions.config['graphql_client']['object'].toString());

    buffer.writeln(sourceCode);

    return "${buffer.toString()}";
  }

  String clear_argumetns(String sourceCode) {
    sourceCode = sourceCode.replaceAll('variables: event.args', '');
    sourceCode = sourceCode.replaceAll('final TemplateArguments? args;', '');
    sourceCode =
        sourceCode.replaceAll('final TemplateArguments? withArgs;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments args;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments withArgs;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments? args;', '');
    sourceCode = sourceCode.replaceAll('TemplateArguments? withArgs;', '');

    sourceCode = sourceCode.replaceAll(', this.withArgs', '');
    sourceCode = sourceCode.replaceAll(', this.args', '');
    sourceCode = sourceCode.replaceAll('this.withArgs', '');
    sourceCode = sourceCode.replaceAll('this.args', '');
    sourceCode = sourceCode.replaceAll('event.withArgs', '');
    sourceCode = sourceCode.replaceAll('event.args', '');
    sourceCode = sourceCode.replaceAll('withArgs', '');
    sourceCode = sourceCode.replaceAll('args', '');
    return sourceCode;
  }

  ClassElement getClass(LibraryReader library) {
    return library.classes.firstWhere((e) =>
        e.displayName.contains('\$Query') ||
        e.displayName.contains('\$Mutation'));
  }

  getArgumentsClass(LibraryReader library) {
    final argumentClass = library.classes
        .firstWhere((e) =>
            e.displayName == getClass(library).displayName.replaceAll("\$", ""))
        .fields
        .where((e) => e.type.toString().endsWith("Arguments"));
    return (argumentClass.isEmpty) ? null : argumentClass.first;
  }

  String getClassName(LibraryReader library) {
    return getClass(library)
        .displayName
        .replaceAll('\$Query', '')
        .replaceAll('\$Mutation', '');
  }

  void imports(LibraryReader library, buildStep) {
    var imports = StringBuffer();
    imports.writeln('import \'package:' +
        ((isQuery(library))
            ? 'hydrated_bloc/hydrated_bloc.dart\';'
            : 'flutter_bloc/flutter_bloc.dart\';'));

    imports.write(
        'import \'package:${builderOptions.config['graphql_client']['import'].toString()}\';');
    updateImports(buildStep, imports.toString());
  }

  String hydratedEditor(LibraryReader library, String sourceCode) {
    try {
      FieldElement nodeField = getClass(library).fields.firstWhere((e) {
        return e.type.toString().contains("Node") ||
            e.type.toString().contains("Payload") ||
            e.type.toString().contains("Mutation");
      });

      if (isQuery(library) &&
          nodeField.type.toString().contains("Connection")) {
        sourceCode = sourceCode
            .replaceAll('Bloc<', 'HydratedBloc<')
            .replaceAll('// fromJsonPlaceholder', fromJsonTemplate)
            .replaceAll('// toJsonPlaceholder', toJsonTemplate);
        if (getArgumentsClass(library) == null) {
          sourceCode = sourceCode.replaceAll(
              'return TemplateLoadedState(TemplateNodeConnection.fromJson(json), null);',
              'return TemplateLoadedState(TemplateNodeConnection.fromJson(json));');
        }
        if (hasPageInfo(library, nodeField) &&
            getArgumentsClass(library) != null) {
          sourceCode = loadMoreHandelerEdit(sourceCode);
        }
      }
      sourceCode = sourceCode
          .replaceAll('#rootNode', nodeField.displayName)
          .replaceAll('TemplateNodeConnection',
              nodeField.type.toString().replaceAll("?", ""));
      return sourceCode;
    } catch (e) {
      sourceCode = sourceCode.replaceAll('#rootNode', 'rootNode');
      return sourceCode;
    }
  }

  String loadMoreHandelerEdit(String sourceCode) {
    sourceCode = sourceCode
        .replaceAll(
            '// loadMoreEventHandlerPlaceholder', loadMoreHandlerTemplate)
        .replaceAll('// loadMoreMethodPlaceholder', loadMoreMethodTemplate)
        .replaceAll('// loadMoreEventPlaceholder', loadMoreEventTemplate)
        .replaceAll('// coursorUpdatePlaceholder', coursorUpdateTemplate);
    return sourceCode;
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
  class TemplateBloc extends Bloc<TemplateEvent, TemplateState> {
    TemplateBloc() : super(TemplateInitial());
    
    @override
    Stream<TemplateState> mapEventToState(TemplateEvent event) async*{
      if(event is LoadTemplateEvent) {
        final client = GraphQL.instance;
        client.then((client) => client
            .execute(TemplateQuery(variables: event.args))
            .then((response) => (response.errors == null)
            ? this.add(TemplateLoadedEvent(response.data?.#rootNode, event.args))
            : this.add(TemplateErrorEvent(response.errors)))
            .catchError((error) => this.add(TemplateExceptionEvent(error))));
      // loadMoreEventHandlerPlaceholder
      } else if (event is TemplateLoadedEvent){
         yield TemplateLoadedState(event.#rootNode, event.withArgs);
      } else if (event is TemplateErrorEvent){
        yield TemplateErrorState(event.errors);
      } else if (event is TemplateExceptionEvent){
        yield TemplateExceptionState(event.exception);
      }
    }
    
    // loadMoreMethodPlaceholder

    // fromJsonPlaceholder
    
    // toJsonPlaceholder
  }
  
  // Events
  abstract class TemplateEvent extends Equatable {
    const TemplateEvent();
  }
  
  
  class LoadTemplateEvent extends TemplateEvent {
    TemplateArguments args;
    LoadTemplateEvent(this.args);
  
    @override
    List<Object> get props => [args];
  }
  
  // loadMoreEventPlaceholder
  class LoadingTemplateEvent extends TemplateEvent {
    LoadingTemplateEvent();
  
    @override
    List<Object> get props => [];
  }
  
  class TemplateLoadedEvent extends TemplateEvent {
    final #rootNode;
    final TemplateArguments? withArgs;
    
    TemplateLoadedEvent(this.#rootNode, this.withArgs);
  
    @override
    List<Object> get props => [#rootNode];
  }
  
  class TemplateLoadedMoreEvent extends TemplateEvent {
    final #rootNode;
    final TemplateArguments? withArgs;
    
    TemplateLoadedMoreEvent(this.#rootNode, this.withArgs);
  
    @override
    List<Object> get props => [#rootNode];
  }
  
  class TemplateErrorEvent extends TemplateEvent {
    final errors;
    TemplateErrorEvent(this.errors);
  
    @override
    List<Object> get props => [errors];
  }
  
  class TemplateExceptionEvent extends TemplateEvent {
    final exception;
    TemplateExceptionEvent(this.exception);
  
    @override
    List<Object> get props => [exception];
  }
  // States
  abstract class TemplateState extends Equatable {
    const TemplateState();
  }
  
  class TemplateInitial extends TemplateState {
    @override
    List<Object> get props => [];
  }
  
  
  class TemplateLoadingState extends TemplateState {
    @override
    List<Object> get props => [];
  }
  
  
  class TemplateLoadedState extends TemplateState {
    TemplateNodeConnection #rootNode;
    final TemplateArguments? withArgs;
  
    TemplateLoadedState(this.#rootNode, this.withArgs);
    
    @override
    List<Object> get props => [#rootNode];
  }
  
  
  class TemplateErrorState extends TemplateState {
    final errors;
  
    TemplateErrorState(this.errors);
    
    @override
    List<Object> get props => [this.errors];
  }
  
  
  class TemplateExceptionState extends TemplateState {
    final exception;
  
    TemplateExceptionState(this.exception);
    
    @override
    List<Object> get props => [this.exception];
  }""";

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
   } else if (event is LoadMoreTemplateEvent) {
        final state = this.state;
        if (state is TemplateLoadedState) {
          final client = GraphQL.instance;
          dynamic args =  state.withArgs;
          // coursorUpdatePlaceholder
          client.then((client) => client
              .execute(TemplateQuery(variables: args))
              .then((response) => (response.errors == null)
                  ? #rootNodeLoadedMore(response.data?.#rootNode, state)
                  : this.add(TemplateErrorEvent(response.errors)))
              .catchError(
                  (error) => this.add(TemplateExceptionEvent(error))));
        }
  """;

  late String loadMoreMethodTemplate = """
  void #rootNodeLoadedMore(
      TemplateNodeConnection? #rootNode, TemplateLoadedState state) {
      #rootNode?.edges = state.#rootNode.edges + #rootNode.edges;
      this.add(TemplateLoadedEvent(#rootNode, state.withArgs));
    }
  """;

  late String coursorUpdateTemplate = """
  if (state.#rootNode.pageInfo != null) {
     args.startsWith = state.#rootNode.pageInfo.endCursor;
  }
  """;

  bool isQuery(LibraryReader library) {
    return library.classes
        .where((e) => e.displayName.contains('\$Query'))
        .isNotEmpty;
  }
}
