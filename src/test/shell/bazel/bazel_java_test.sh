#!/bin/bash
#
# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Tests the examples provided in Bazel
#

# Load test environment
source $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-setup.sh \
  || { echo "test-setup.sh not found!" >&2; exit 1; }

function write_hello_library_files() {
  mkdir -p java/main
  cat >java/main/BUILD <<EOF
java_binary(name = 'main',
    deps = ['//java/hello_library'],
    srcs = ['Main.java'],
    main_class = 'main.Main')
EOF

  cat >java/main/Main.java <<EOF
package main;
import hello_library.HelloLibrary;
public class Main {
  public static void main(String[] args) {
    HelloLibrary.funcHelloLibrary();
    System.out.println("Hello, World!");
  }
}
EOF

  mkdir -p java/hello_library
  cat >java/hello_library/BUILD <<EOF
package(default_visibility=['//visibility:public'])
java_library(name = 'hello_library',
             srcs = ['HelloLibrary.java']);
EOF

  cat >java/hello_library/HelloLibrary.java <<EOF
package hello_library;
public class HelloLibrary {
  public static void funcHelloLibrary() {
    System.out.print("Hello, Library!;");
  }
}
EOF
}

function test_build_hello_world() {
  write_hello_library_files

  bazel build //java/main:main &> $TEST_log || fail "build failed"
}

function test_errorprone_error_fails_build_by_default() {
  write_hello_library_files
  # Trigger an error-prone error by comparing two arrays via #equals().
  cat >java/hello_library/HelloLibrary.java <<EOF
package hello_library;
public class HelloLibrary {
  public static boolean funcHelloLibrary() {
    int[] arr1 = {1, 2, 3};
    int[] arr2 = {1, 2, 3};
    return arr1.equals(arr2);
  }
}
EOF

  bazel build //java/main:main &> $TEST_log && fail "build should have failed" || true
  expect_log "error: \[ArrayEquals\] Reference equality used to compare arrays"
}

function test_extrachecks_off_disables_errorprone() {
  write_hello_library_files
  # Trigger an error-prone error by comparing two arrays via #equals().
  cat >java/hello_library/HelloLibrary.java <<EOF
package hello_library;
public class HelloLibrary {
  public static boolean funcHelloLibrary() {
    int[] arr1 = {1, 2, 3};
    int[] arr2 = {1, 2, 3};
    return arr1.equals(arr2);
  }
}
EOF
  # Disable error-prone for this target, though.
  cat >java/hello_library/BUILD <<EOF
package(default_visibility=['//visibility:public'])
java_library(name = 'hello_library',
             srcs = ['HelloLibrary.java'],
             javacopts = ['-extra_checks:off'],);
EOF

  bazel build //java/main:main &> $TEST_log || fail "build failed"
  expect_not_log "error: \[ArrayEquals\] Reference equality used to compare arrays"
}

run_suite "Java integration tests"
