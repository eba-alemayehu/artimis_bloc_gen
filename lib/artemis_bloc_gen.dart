library artemis_bloc_gen;

import 'package:artemis_bloc_gen/src/artemis_list_generator.dart';
import 'package:build/build.dart';
import 'package:artemis_bloc_gen/src/artemis_bloc_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder artemisBlocBuilder(BuilderOptions options) => LibraryBuilder(
  GqlBlocGenerator(options),
  generatedExtension: '.bloc.dart',
);

Builder artemisListBuilder(BuilderOptions options) => LibraryBuilder(
  GqlListGenerator(options),
  generatedExtension: '.list.dart',
);
//
// Builder metadataLibraryBuilder(BuilderOptions options) => LibraryBuilder(
//   GqlBlocGenerator(options),
//   generatedExtension: '.bloc.dart',
// );