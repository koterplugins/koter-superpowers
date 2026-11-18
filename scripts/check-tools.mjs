// Fails when a skill or command cites, between backticks, a Koter MCP tool that is not in scripts/tools-list.json.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const tools = new Set(JSON.parse(readFileSync(join(root, 'scripts/tools-list.json'), 'utf8')).map((t) => t.name));

// Backticked snake_case words that are not Koter MCP tools.
const notTools = new Set([
  // enum values and onboarding state keys
  'b_cotar', 'com_vendedores', 'cotacao_vidas', 'em_andamento', 'faixa_de_vidas', 'last_message',
  'nao_se_aplica', 'not_equals', 'pre_requisitos_de_tela', 'usou_de_verdade', 'work_schedule',
  // fields of OAuth and of other AI hosts
  'client_id', 'is_background',
  // tools of the KoterZap customer agent
  'compare_quote_products', 'consultar_base_conhecimento', 'create_lead', 'create_lead_note', 'create_quote',
  'fetch_crm_context', 'fetch_markets_by_approximate_name', 'get_market_by_id', 'get_product_details', 'get_quote',
  'list_contacts', 'list_leads', 'save_contact', 'save_lead', 'save_note', 'save_task', 'search_quote_network',
  'search_quote_options', 'send_quote_pdf', 'share_market_links', 'transfer_to_human', 'update_contact',
  'update_lead', 'update_quote', 'validate_quote_prices',
]);
// Keys of the auto multi-quote form.
const formKey = /^(condutor|endereco|questionario|segurado|veiculo|vigencia)_/;

// `tool_name` or `tool_name(args)`
const citation = /`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)(?:\([^`]*\))?`/g;

const unknown = [];
for (const dir of ['skills', 'commands']) {
  for (const file of readdirSync(join(root, dir), { recursive: true })) {
    if (!file.endsWith('.md')) continue;
    const path = join(dir, file);
    readFileSync(join(root, path), 'utf8').split('\n').forEach((line, i) => {
      for (const [, name] of line.matchAll(citation)) {
        if (!tools.has(name) && !notTools.has(name) && !formKey.test(name)) unknown.push(`${path}:${i + 1}: ${name}`);
      }
    });
  }
}

if (unknown.length) {
  console.error(`${unknown.join('\n')}\n\n${unknown.length} citation(s) of tools that are not in scripts/tools-list.json.`);
  process.exit(1);
}
console.log(`ok: every cited tool exists (${tools.size} tools in the list)`);
