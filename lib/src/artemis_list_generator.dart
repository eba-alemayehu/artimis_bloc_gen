import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

class GqlListGenerator extends Generator {
  final BuilderOptions builderOptions;

  GqlListGenerator(this.builderOptions);

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    var buffer = StringBuffer();
    // buffer.writeln(imports(library));

    final className = getClass(library).displayName;
    print(className);
    String sourceCode = template
        .replaceAll('{className}', getClassName(library))
        .replaceAll('{rootNode}', getRootNode(library).displayName)
        .replaceAll(
            '{argsDeclaration}',
            getArgumentsClass(library) == null
                ? ''
                : 'final ${getClassName(library)}Arguments args;')
        .replaceAll('{argsParam}',
            getArgumentsClass(library) == null ? '' : ', required this.args')
        .replaceAll(
            '{args}', getArgumentsClass(library) == null ? '' : 'widget.args');

    buffer.writeln(imports(library));
    buffer.writeln(sourceCode);

    // print(buffer.toString());
    return !hasEdges(library) ? "// Has no list" : buffer.toString();
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
        e.displayName.contains('\$Query') ||
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
    import 'package:easy_localization/easy_localization.dart';
    import 'package:flutter/material.dart';
    import 'package:flutter_bloc/flutter_bloc.dart';
    import 'package:flutter_svg/flutter_svg.dart';
    import 'package:observe_internet_connectivity/observe_internet_connectivity.dart';
    import 'package:pull_to_refresh/pull_to_refresh.dart'
        show RefreshController, SmartRefresher, WaterDropHeader;
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
      print(e);
      sourceCode = sourceCode.replaceAll('#rootNode', 'rootNode');
      return sourceCode;
    }
  }

  String loadMoreHandelerEdit(String sourceCode) {
    sourceCode = sourceCode
        .replaceAll('// loadMoreEventHandlerPlaceholderOn',
            'on<LoadMoreTemplateEvent>(_onLoadMoreTemplateEvent);')
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
  
class {className}List extends StatefulWidget {
  final Function? onSelect;
  final Function build;
  final Widget shimmer;
  final Function buildError;
  final Function buildEmpty;
  final Function buildConnectionError;
  final int numberOfSimmers;
  final String connectionErrorMsg;
  
  {argsDeclaration}
  
  const {className}List(
      {Key? key,
      this.onSelect, 
      required this.build, 
      required this.buildError, 
      required this.buildEmpty, 
      required this.buildConnectionError, 
      this.numberOfSimmers = 5, 
      this.connectionErrorMsg = "Failed: Please check your internet connection.",
      required this.shimmer {argsParam}})
      : super(key: key);

  @override
  State<{className}List> createState() => _{className}ListState();
}

class _{className}ListState extends State<{className}List> {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  List<Widget> {rootNode} = [];

  @override
  void initState() {
    BlocProvider.of<{className}Bloc>(context)
        .add(Load{className}Event({args}));
    {rootNode}  = [];
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<{className}Bloc, {className}State>(
      listener: (context, state) {
        if (state is {className}Initial) {
          final TabController controller = DefaultTabController.of(context)!;

          controller.addListener(() {
            BlocProvider.of<{className}Bloc>(context).add(Load{className}Event({args}));
            {rootNode} = [];
          });
        }
      },
      builder: (context, state) {
        print(state);
        if (state is {className}LoadedState) {
          {rootNode} = state.{rootNode}.edges
              .map((e) => e?.node)
              .map<Widget>((e)=> widget.build.call(context, e))
              .toList();
        } else if (state is {className}LoadingState && {rootNode}.isEmpty) {
          {rootNode} = List.generate(
              widget.numberOfSimmers,
              (index) => widget.shimmer);
        } else if (state is {className}ErrorState && {rootNode}.isEmpty) {
            return widget.buildError.call(context,state.errors);
        } else if (state is {className}ExceptionState && {rootNode}.isEmpty) {
          if ({rootNode}.isNotEmpty) {
            return FutureBuilder(
                future: InternetConnectivity().hasInternetConnection,
                builder: (context, snapshot) {
                  if (snapshot.data == false) {
                    return widget.buildConnectionError.call(context);
                  } else {
                    return widget.buildError.call(context,state.exception);
                  }
                });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.red,
              content: Text(widget.connectionErrorMsg),
            ));
          }
        }
        if ({rootNode}.isEmpty && state is {className}LoadedState) {
          return widget.buildEmpty.call(context);
        }
        return SmartRefresher(
          enablePullDown: true,
          enablePullUp: false,
          header: const WaterDropHeader(),
          controller: _refreshController,
          onRefresh: refresh,
          onLoading: loading,
          child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12),
              itemCount: {rootNode}.length,
              itemBuilder: (context, i) => {rootNode}[i]),
        );
      },
    );
  }

  Future<void> refresh() async {
    BlocProvider.of<{className}Bloc>(context).add(Load{className}Event({args}));
    await BlocProvider.of<{className}Bloc>(context)
        .stream
        .firstWhere((state) => state is! {className}LoadingState);
    _refreshController.refreshCompleted();
  }

  Future<void> loading() async {
    BlocProvider.of<{className}Bloc>(context).add(Load{className}Event({args}));
    await BlocProvider.of<{className}Bloc>(context)
        .stream
        .firstWhere((state) => state is! {className}LoadingState);
    _refreshController.loadComplete();
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
}
