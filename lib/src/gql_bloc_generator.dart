import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class GqlBlocGenerator extends Generator {
  final BuilderOptions builderOptions;

  GqlBlocGenerator(this.builderOptions);

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    var buffer = StringBuffer();
    var imports = StringBuffer();
    imports.writeln('import \'package:flutter_bloc/flutter_bloc.dart\';');
    imports.write(
        'import \'package:${builderOptions.config['graphql_client']['import'].toString()}\';');
    updateImports(buildStep, imports.toString());
    final className = library.classes
        .firstWhere((e) =>
            e.displayName.contains('\$Query') ||
            e.displayName.contains('\$Mutation'))
        .displayName;

    String sourceCode = template;
    if (library.classes
        .where((e) => e.displayName.contains('Arguments'))
        .isEmpty) {
      buffer.writeln('/*${library.classes}*/');
      sourceCode = sourceCode
          .replaceAll('variables: event.args', '');
    }
    sourceCode = sourceCode
        .replaceAll('TemplateQuery', className.replaceAll('\$', ''))
        .replaceAll('Template', className)
        .replaceAll('GraphQL.instance',
            builderOptions.config['graphql_client']['object'].toString())
        .replaceAll('\$Query', '')
        .replaceAll('\$Mutation', '');
    buffer.writeln(sourceCode);

    return "${buffer.toString()}";
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
            ? this.add(TemplateLoadedEvent(response))
            : this.add(TemplateErrorEvent(response.errors)))
            .catchError((error) => this.add(TemplateExceptionEvent(error))));
      } else if (event is TemplateLoadedEvent){
         yield TemplateLoadedState(event.response);
      } else if (event is TemplateErrorEvent){
        yield TemplateErrorState(event.errors);
      } else if (event is TemplateExceptionEvent){
        yield TemplateExceptionState(event.exception);
      }
    }
  }
  
  // Events
  abstract class TemplateEvent extends Equatable {
    const TemplateEvent();
  }
  
  
  class LoadTemplateEvent extends TemplateEvent {
    final args;
    LoadTemplateEvent(this.args);
  
    @override
    List<Object> get props => [args];
  }
  
  class LoadingTemplateEvent extends TemplateEvent {
    LoadingTemplateEvent();
  
    @override
    List<Object> get props => [];
  }
  
  class TemplateLoadedEvent extends TemplateEvent {
    final response;
  
    TemplateLoadedEvent(this.response);
  
    @override
    List<Object> get props => [response];
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
    final response;
  
    TemplateLoadedState(this.response);
    
    @override
    List<Object> get props => [response];
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
}
