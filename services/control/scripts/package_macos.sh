#!/bin/sh
set -eu
PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH
control_project_root=$(cd "$PROJECT_DIR/.." && pwd)
control_package="$control_project_root/services/control"
control_output="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/control"
mkdir -p "$control_output"
control_count=0
for control_arch in ${ARCHS:-$(uname -m)}; do
  case "$control_arch" in
    arm64) control_target=aarch64-apple-darwin ;;
    x86_64) control_target=x86_64-apple-darwin ;;
    *) exit 1 ;;
  esac
  cargo build --locked --release --manifest-path "$control_package/Cargo.toml" --target "$control_target"
  control_artifacts="$control_package/target/$control_target/release"
  control_count=$((control_count + 1))
  for control_file in flclashctl libflclash_control.dylib; do
    if [ "$control_count" -eq 1 ]; then
      cp "$control_artifacts/$control_file" "$control_output/$control_file"
    else
      /usr/bin/lipo -create "$control_output/$control_file" "$control_artifacts/$control_file" -output "$control_output/$control_file.universal"
      mv "$control_output/$control_file.universal" "$control_output/$control_file"
    fi
  done
done
chmod 755 "$control_output/flclashctl" "$control_output/libflclash_control.dylib"
control_identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ -z "$control_identity" ]; then control_identity=-; fi
/usr/bin/codesign --force --sign "$control_identity" --options runtime "$control_output/libflclash_control.dylib"
/usr/bin/codesign --force --sign "$control_identity" --options runtime "$control_output/flclashctl"
/usr/bin/codesign --verify --strict "$control_output/libflclash_control.dylib"
/usr/bin/codesign --verify --strict "$control_output/flclashctl"
