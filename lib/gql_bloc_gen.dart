library gql_bloc_gen;

import 'package:build/build.dart';
import 'package:gql_bloc_gen/src/gql_bloc_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder gqlBlogBuilder(BuilderOptions options) =>
    SharedPartBuilder([GqlBlocGenerator(options)], 'gqlBlocGen');
