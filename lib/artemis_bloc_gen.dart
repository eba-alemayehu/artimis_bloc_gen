library artemis_bloc_gen;

import 'package:build/build.dart';
import 'package:artemis_bloc_gen/src/artemis_bloc_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder artemisBlocBuilder(BuilderOptions options) => LibraryBuilder(
  GqlBlocGenerator(options),
  generatedExtension: '.bloc.dart',
);

//
// Builder metadataLibraryBuilder(BuilderOptions options) => LibraryBuilder(
//   GqlBlocGenerator(options),
//   generatedExtension: '.bloc.dart',
// );