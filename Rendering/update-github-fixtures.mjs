// Explicit maintenance command, never run by tests or CI. Responses are checked
// in so tests work offline and changes in GitHub's renderer remain reviewable.
import {readFile, writeFile} from 'node:fs/promises';
const path = new URL('../Tests/Rendering/github-rendering.json', import.meta.url);
const fixture = JSON.parse(await readFile(path, 'utf8'));
const updated = [];
for (const item of fixture.cases) {
  const response = await fetch(fixture.endpoint, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'User-Agent': 'mdViewer-compatibility-tests'},
    body: JSON.stringify({text: item.source, mode: fixture.mode}),
  });
  if (!response.ok) throw new Error(`GitHub ${response.status}: ${await response.text()}`);
  updated.push({...item, expected: await response.text()});
}
await writeFile(path, JSON.stringify({...fixture, fetchedAt: new Date().toISOString(), cases: updated}, null, 2) + '\n');
console.log(`Recorded ${updated.length} GitHub rendering responses`);
