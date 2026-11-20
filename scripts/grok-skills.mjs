// Writes one folder per skill (nome.txt, descricao.txt, instrucoes.txt) into the directory given as argument, for the Grok package.
// instrucoes.txt is the SKILL.md body with every cited references/*.md appended as an "Anexo" section, and the command that opens the skill on top.
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const skillsDir = join(root, 'plugins/koter/skills');
const commandsDir = join(root, 'plugins/koter/commands');
const out = process.argv[2];
if (!out) throw new Error('usage: node scripts/grok-skills.mjs <output dir>');

const skills = readdirSync(skillsDir).filter((s) => existsSync(join(skillsDir, s, 'SKILL.md'))).sort();

function splitFrontmatter(text, file) {
  const match = /^---\n([\s\S]*?)\n---\n/.exec(text);
  if (!match) throw new Error(`${file}: no frontmatter`);
  const fields = {};
  for (const line of match[1].split('\n')) {
    const [, key, value] = /^(\w+):\s*(.*)$/.exec(line) ?? [];
    if (key) fields[key] = value.startsWith('"') ? JSON.parse(value) : value;
  }
  return { fields, body: text.slice(match[0].length).trim() };
}

// key "<skill>/<name>" -> { skill, title, body }; byName resolves `name.md` when only one skill has it.
const refs = new Map();
const byName = new Map();
for (const skill of skills) {
  const dir = join(skillsDir, skill, 'references');
  if (!existsSync(dir)) continue;
  for (const file of readdirSync(dir).filter((f) => f.endsWith('.md'))) {
    const [first, ...rest] = readFileSync(join(dir, file), 'utf8').split('\n');
    if (!first.startsWith('# ')) throw new Error(`${skill}/references/${file}: the first line must be the # title`);
    const name = file.slice(0, -3);
    refs.set(`${skill}/${name}`, { skill, title: first.slice(2).trim(), body: rest.join('\n').trim() });
    byName.set(name, byName.has(name) ? null : `${skill}/${name}`);
  }
}

// `references/x.md`, `../other-skill/references/x.md`, `skills/other-skill/references/x.md`, with or without backticks.
const cited = /(`?)((?:[\w.-]+\/)*)references\/([a-z0-9-]+)\.md\1/g;
// `x.md`, a sibling reference cited by file name.
const bare = /`([a-z0-9-]+)\.md`/g;

function citedKey(prefix, name, owner, where) {
  const segment = prefix.split('/').filter(Boolean).pop();
  const key = `${skills.includes(segment) ? segment : owner}/${name}`;
  if (!refs.has(key)) throw new Error(`${where}: cites ${prefix}references/${name}.md, which does not exist`);
  return key;
}

function bareKey(name, owner) {
  return refs.has(`${owner}/${name}`) ? `${owner}/${name}` : byName.get(name);
}

function embeddedKeys(texts) {
  const keys = [];
  const queue = texts.map(([text, owner, where]) => ({ text, owner, where }));
  while (queue.length) {
    const { text, owner, where } = queue.shift();
    for (const [, , prefix, name] of text.matchAll(cited)) {
      const key = citedKey(prefix, name, owner, where);
      if (keys.includes(key)) continue;
      keys.push(key);
      queue.push({ text: refs.get(key).body, owner: refs.get(key).skill, where: `${key}.md` });
    }
  }
  return keys;
}

function rewrite(text, owner, labels, where) {
  return text
    .replace(cited, (_, _tick, prefix, name) => `"${labels.get(citedKey(prefix, name, owner, where))}"`)
    .replace(bare, (match, name) => {
      const key = bareKey(name, owner);
      if (!key) return match;
      if (labels.has(key)) return `"${labels.get(key)}"`;
      return `"${refs.get(key).title}" (habilidade ${refs.get(key).skill})`;
    });
}

// skill -> the command that opens it, as a short note.
const notes = new Map();
for (const file of readdirSync(commandsDir).filter((f) => f.endsWith('.md'))) {
  const { body } = splitFrontmatter(readFileSync(join(commandsDir, file), 'utf8'), `commands/${file}`);
  const skill = /^Use a skill `([a-z0-9-]+)`/m.exec(body)?.[1];
  if (!skills.includes(skill)) throw new Error(`commands/${file}: does not open a known skill`);
  const command = `/${file.slice(0, -3)}`;
  const rest = body
    .split('\n')
    .filter((line) => !/^Use a skill `|^Argumentos \(opcionais\): \$ARGUMENTS/.test(line))
    .join('\n')
    .trim();
  notes.set(skill, `**Comando \`${command}\`.** Se o corretor digitar \`${command}\`, sozinho ou com um complemento, siga:\n\n${rest}`);
}

for (const skill of skills) {
  const where = `${skill}/SKILL.md`;
  const { fields, body } = splitFrontmatter(readFileSync(join(skillsDir, where), 'utf8'), where);
  if (fields.name !== skill || !fields.description) throw new Error(`${where}: name must match the folder and description must be set`);

  const note = notes.get(skill);
  const keys = embeddedKeys([[body, skill, where], ...(note ? [[note, skill, `note of ${where}`]] : [])]);
  const labels = new Map(keys.map((key, i) => [key, `Anexo ${i + 1} · ${refs.get(key).title}`]));

  let text = rewrite(body, skill, labels, where);
  if (note) {
    const noteText = rewrite(note, skill, labels, where);
    text = text.startsWith('# ') ? text.replace(/^# .*\n+/, (title) => `${title.trimEnd()}\n\n${noteText}\n\n`) : `${noteText}\n\n${text}`;
  }
  for (const key of keys) {
    const ref = refs.get(key);
    text += `\n\n# ${labels.get(key)}\n\n${rewrite(ref.body, ref.skill, labels, `${key}.md`)}`;
  }

  const dir = join(out, skill);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'nome.txt'), `${fields.name}\n`);
  writeFileSync(join(dir, 'descricao.txt'), `${fields.description}\n`);
  writeFileSync(join(dir, 'instrucoes.txt'), `${text}\n`);
}
