// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.all_test;

import 'dependencies_test.dart' as dependencies_test;
import 'navigation_test.dart' as navigation_test;
import 'utils_test.dart' as utils_test;

main() {
  dependencies_test.defineTests();
  navigation_test.defineTests();
  utils_test.defineTests();
}
