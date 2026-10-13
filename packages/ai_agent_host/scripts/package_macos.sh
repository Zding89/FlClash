#!/bin/sh
set -eu
PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:$PATH"
export PATH
ai_project_root=$(cd "$PROJECT_DIR/.." && pwd)
ai_package_dir="$ai_project_root/packages/ai_agent_host"
ai_resources="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
cd "$ai_package_dir"
if [ ! -d node_modules/esbuild ]; then
  pnpm install --frozen-lockfile --ignore-scripts
fi
ai_archs="${ARCHS:-$(uname -m)}"
ai_count=0
for ai_arch in $ai_archs; do
  case "$ai_arch" in
    arm64) ai_node_arch=arm64 ;;
    x86_64) ai_node_arch=x64 ;;
    *) exit 1 ;;
  esac
  ai_staging="$ai_project_root/.dart_tool/ai_host/$ai_arch/Resources"
  node scripts/package.mjs --arch "$ai_node_arch" --resources "$ai_staging"
  mkdir -p "$ai_resources/ai"
  cp "$ai_staging/ai/host.mjs" "$ai_staging/ai/script_runner.mjs" "$ai_staging/ai/NODE-LICENSE" "$ai_staging/ai/manifest.json" "$ai_resources/ai/"
  ai_count=$((ai_count + 1))
  if [ "$ai_count" -eq 1 ]; then
    cp "$ai_staging/ai/node" "$ai_resources/ai/node"
  else
    /usr/bin/lipo -create "$ai_resources/ai/node" "$ai_staging/ai/node" -output "$ai_resources/ai/node.universal"
    mv "$ai_resources/ai/node.universal" "$ai_resources/ai/node"
  fi
done
chmod 755 "$ai_resources/ai/node"
ai_signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ -z "$ai_signing_identity" ]; then ai_signing_identity=-; fi
/usr/bin/codesign --force --sign "$ai_signing_identity" --options runtime --entitlements "$ai_package_dir/scripts/node.entitlements" "$ai_resources/ai/node"
node "$ai_package_dir/scripts/finalize_manifest.mjs" "$ai_project_root" "$ai_resources" $ai_archs
