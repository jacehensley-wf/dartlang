// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library atom.utils;

import 'dart:async';

import 'package:logging/logging.dart';

final String loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing "
    "elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
    "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi "
    "ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit"
    " in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur"
    " sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt "
    "mollit anim id est laborum.";

final Logger _logger = new Logger('atom.utils');

/// Ensure the first letter is lower-case.
String toStartingLowerCase(String str) {
  if (str == null) return null;
  if (str.isEmpty) return str;
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}

String toTitleCase(String str) {
  if (str == null) return null;
  if (str.isEmpty) return str;
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

String pluralize(String word, int count) {
  if (count == 1) return word;
  if (word.endsWith('s')) return '${word}es';
  return '${word}s';
}

String commas(int n) {
  String str = '${n}';
  int len = str.length;
  // if (len > 6) {
  //   int pos1 = len - 6;
  //   int pos2 = len - 3;
  //   return '${str.substring(0, pos1)},${str.substring(pos1, pos2)},${str.substring(pos2)}';
  // } else
  if (len > 3) {
    int pos = len - 3;
    return '${str.substring(0, pos)},${str.substring(pos)}';
  } else {
    return str;
  }
}

final RegExp idRegex = new RegExp(r'[_a-zA-Z0-9]');

class Edit {
  final int offset;
  final int length;
  final String replacement;

  Edit(this.offset, this.length, this.replacement);

  bool operator==(obj) {
    if (obj is! Edit) return false;
    Edit other = obj;
    return offset == other.offset && length == other.length &&
        replacement == other.replacement;
  }

  int get hashCode => offset ^ length ^ replacement.hashCode;

  String toString() => "[Edit ${offset}:${length}:'${replacement}']";
}

/// A value that fires events when it changes.
class Property<T> {
  T _value;
  StreamController<T> _controller = new StreamController.broadcast();

  Property([T initialValue]) {
    _value = initialValue;
  }

  T get value => _value;
  set value(T v) {
    if (_value != v) {
      _value = v;
      _controller.add(_value);
    }
  }

  bool get hasValue => _value != null;

  Stream<T> get onChanged => _controller.stream;

  StreamSubscription<T> observe(callback(T t)) {
    callback(value);
    return onChanged.listen(callback);
  }

  String toString() => '${_value}';
}

/// A SelectionGroup:
/// - manages a set of items
/// - fires notifications when the set changes
/// - has a notion of a 'selected' or active item
class SelectionGroup<T> {
  T _selection;
  List<T> _items = [];

  StreamController<T> _addedController = new StreamController.broadcast();
  StreamController<T> _selectionChangedController = new StreamController.broadcast();
  StreamController<T> _removedController = new StreamController.broadcast();
  StreamController<T> _mutationController = new StreamController.broadcast();

  SelectionGroup();

  T get selection => _selection;

  List<T> get items => _items;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;

  Stream<T> get onAdded => _addedController.stream;
  Stream<T> get onSelectionChanged => _selectionChangedController.stream;
  Stream<T> get onRemoved => _removedController.stream;

  StreamSubscription<List<T>> observeMutation(callback(List<T> list)) {
    callback(items);
    return _mutationController.stream.map((_) => items).listen(callback);
  }

  void add(T item) {
    _items.add(item);
    _addedController.add(item);
    _mutationController.add(item);

    if (_selection == null) {
      _selection = item;
      _selectionChangedController.add(selection);
    }
  }

  void setSelection(T sel) {
    if (_selection != sel) {
      _selection = sel;
      _selectionChangedController.add(selection);
    }
  }

  void remove(T item) {
    if (!_items.contains(item)) return;

    _items.remove(item);
    _removedController.add(item);
    _mutationController.add(item);

    if (_selection == item) {
      _selection = null;
      _selectionChangedController.add(null);
    }
  }
}

class FutureSerializer<T> {
  List _operations = [];
  List<Completer<T>> _completers = [];

  Future<T> perform(Function operation) {
    Completer<T> completer = new Completer();

    _operations.add(operation);
    _completers.add(completer);

    if (_operations.length == 1) {
      _serviceQueue();
    }

    return completer.future;
  }

  void _serviceQueue() {
    Function operation = _operations.first;
    Completer<T> completer = _completers.first;

    Future future = operation();
    future.then((value) {
      completer.complete(value);
    }).catchError((e) {
      completer.completeError(e);
    }).whenComplete(() {
      _operations.removeAt(0);
      _completers.removeAt(0);

      if (_operations.isNotEmpty) _serviceQueue();
    });
  }
}

bool listIdentical(List a, List b) {
  if (a.length != b.length) return false;

  for (int i = 0; i < a.length; i++) {
    var _a = a[i];
    var _b = b[i];
    if (_a == null && _b != null) return false;
    if (_a != null && _b == null) return false;
    if (_a != _b) return false;
  }

  return true;
}

/// Diff the two strings and return the list of edits to convert [a] to [b].
List<Edit> simpleDiff(String a, String b) {
  if (a.isEmpty && b.isNotEmpty) return [new Edit(0, 0, b)];
  if (a.isNotEmpty && b.isEmpty) return [new Edit(0, a.length, b)];
  if (a == b) return [new Edit(0, 0, '')];

  // Look for a single deletion, addition, or replacement edit that will convert
  // [a] to [b]. Else do a wholesale replacement.

  int startA = 0;
  int startB = 0;

  int endA = a.length;
  int endB = b.length;

  while (startA < endA && startB < endB && a[startA] == b[startB]) {
    startA++;
    startB++;
  }

  while (endA > startA && endB > startB && a[endA - 1] == b[endB - 1]) {
    endA--;
    endB--;
  }

  return [
    new Edit(startA, endA - startA, b.substring(startB, endB))
  ];
}
