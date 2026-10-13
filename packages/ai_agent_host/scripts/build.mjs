import { build } from 'esbuild';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
await mkdir(path.join(root, 'dist'), { recursive: true });
const result = await build({ absWorkingDir: root, entryPoints: ['src/main.mjs'], outfile: 'dist/host.mjs', bundle: true, platform: 'node', format: 'esm', target: 'node22', minify: true, sourcemap: false, metafile: true, banner: { js: "import { createRequire as __createRequire } from 'node:module'; const require = __createRequire(import.meta.url);" } });
for (const [input, contribution] of Object.entries(result.metafile.outputs['dist/host.mjs'].inputs)) {
  if (contribution.bytesInOutput > 0 && /node_modules\/(?:@aws-sdk|@google)\//.test(input)) throw new Error('Unexpected provider SDK in bundle');
}
await writeFile(path.join(root, 'dist/metafile.json'), JSON.stringify(result.metafile));
