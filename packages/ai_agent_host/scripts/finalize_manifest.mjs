import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const [projectRoot, resources, ...architectures] = process.argv.slice(2);
if (!projectRoot || !resources || !architectures.length ||
    architectures.some((arch) => !['arm64', 'x86_64'].includes(arch))) {
  throw new Error('Invalid macOS runtime manifest inputs');
}
const manifests = await Promise.all(architectures.map(async (arch) =>
  JSON.parse(await readFile(path.join(projectRoot, '.dart_tool', 'ai_host', arch,
    'Resources', 'ai', 'manifest.json'), 'utf8'))));
const base = manifests[0];
for (const manifest of manifests) {
  if (manifest.nodeVersion !== base.nodeVersion ||
      manifest.piVersion !== base.piVersion ||
      manifest.hostSha256 !== base.hostSha256) {
    throw new Error('Mismatched macOS AI runtime architectures');
  }
}
const target = path.join(resources, 'ai');
const digest = async (name) => createHash('sha256')
  .update(await readFile(path.join(target, name))).digest('hex');
await writeFile(path.join(target, 'manifest.json'), JSON.stringify({
  version: base.version,
  nodeVersion: base.nodeVersion,
  piVersion: base.piVersion,
  arch: manifests.length === 1 ? base.arch : 'universal',
  architectures: manifests.map((manifest) => manifest.arch),
  nodeArchiveSha256ByArch: Object.fromEntries(manifests.map((manifest) =>
    [manifest.arch, manifest.nodeArchiveSha256])),
  nodeBinarySha256: await digest('node'),
  hostSha256: await digest('host.mjs'),
  scriptRunnerSha256: await digest('script_runner.mjs'),
}));
