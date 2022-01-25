# vim: filetype=bash
# This file is a work in progress, designed to replace the complicated test
# orchestration previously placed in TensorFlow's ci_sanity.sh.
# This is not currently in use.
setup_file() {
    cd /tf/tensorflow
    bazel version  # Start the bazel server
    # Only shows Added, Changed, Modified, Renamed, and Type-changed files
    git diff --diff-filter ACMRT --name-only origin/master > $BATS_FILE_TMPDIR/changed_files
    # Query for all targets 
    run bazel query $(sed ':a; N; $!ba; s/\n/ union /g' $BATS_FILE_TMPDIR/changed_files) --keep_going > $BATS_FILE_TMPDIR/changed_targets || true
}

@test "Run bazel nobuild on affected targets" {
    skip
    xargs -a $BATS_FILE_TMPDIR/changed_targets bazel build --experimental_cc_shared_library --jobs=auto --nobuild --deleted_packages="" --
}

@test "Check buildifier formatting on BUILD files" {
    skip
    grep -e 'BUILD' $BATS_FILE_TMPDIR/changed_files | xargs buildifier -v -mode=diff -diff_command=diff
}

@test "Check formatting for C++ files" {
    echo "clang-format is recommended. Here are the files with suggested changes:"
    grep -e '\.h$' -e '\.cc$' $BATS_FILE_TMPDIR/changed_files | xargs -I'{}' -n1 -P $(nproc --all) bash -c 'clang-format-12 --style=Google {} | diff - {} >/dev/null || echo {}' | tee $BATS_TEST_TMPDIR/needs_help.txt
    echo "You can use clang-format --style=Google -i <file> to apply changes to a file."
    test ! -s $BATS_TEST_TMPDIR/needs_help.txt
}

@test "Check pylint for Python files" {
    grep -e "\.py$" $BATS_FILE_TMPDIR/changed_files | xargs python -m pylint --rcfile=tensorflow/tools/ci_build/pylintrc
}

teardown_file() {
    bazel shutdown
}