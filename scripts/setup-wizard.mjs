#!/usr/bin/env node

/**
 * Convex Salesforce Connector - Setup Wizard
 *
 * Interactive setup wizard to configure the connector.
 * Run with: npm run setup
 */

import { createInterface } from 'readline';
import { execSync, spawn } from 'child_process';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = join(__dirname, '..');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
};

const log = {
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  warn: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  step: (n, msg) => console.log(`\n${colors.cyan}[${n}]${colors.reset} ${colors.bright}${msg}${colors.reset}`),
};

// Standard Salesforce objects available for CDC
const STANDARD_OBJECTS = [
  { name: 'Account', value: 'Account', checked: true },
  { name: 'Contact', value: 'Contact', checked: true },
  { name: 'Lead', value: 'Lead', checked: true },
  { name: 'Opportunity', value: 'Opportunity', checked: true },
  { name: 'Task', value: 'Task', checked: false },
  { name: 'Event', value: 'Event', checked: false },
  { name: 'Case', value: 'Case', checked: false },
  { name: 'Campaign', value: 'Campaign', checked: false },
  { name: 'Order', value: 'Order', checked: false },
  { name: 'Product2', value: 'Product2', checked: false },
];

async function prompt(question) {
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function promptYesNo(question, defaultYes = true) {
  const suffix = defaultYes ? '[Y/n]' : '[y/N]';
  const answer = await prompt(`${question} ${suffix}: `);
  if (!answer) return defaultYes;
  return answer.toLowerCase().startsWith('y');
}

async function promptSelect(question, options) {
  console.log(`\n${question}`);
  options.forEach((opt, i) => {
    const marker = opt.checked ? '●' : '○';
    console.log(`  ${i + 1}. ${marker} ${opt.name}`);
  });
  console.log('\nEnter numbers separated by commas (e.g., 1,2,3) or "all":');
  const answer = await prompt('> ');

  if (answer.toLowerCase() === 'all') {
    return options.map(o => o.value);
  }

  const indices = answer.split(',').map(s => parseInt(s.trim()) - 1);
  return indices
    .filter(i => i >= 0 && i < options.length)
    .map(i => options[i].value);
}

function checkPrerequisites() {
  log.step(1, 'Checking prerequisites...');

  let hasErrors = false;

  // Check Node.js
  try {
    const nodeVersion = execSync('node --version', { encoding: 'utf-8' }).trim();
    log.success(`Node.js ${nodeVersion}`);
  } catch {
    log.error('Node.js not found. Please install Node.js 18+');
    hasErrors = true;
  }

  // Check Salesforce CLI
  try {
    const sfVersion = execSync('sf --version', { encoding: 'utf-8' }).split('\n')[0];
    log.success(`Salesforce CLI: ${sfVersion}`);
  } catch {
    log.error('Salesforce CLI not found. Install with: npm install -g @salesforce/cli');
    hasErrors = true;
  }

  // Check Convex
  try {
    execSync('npx convex --version', { encoding: 'utf-8' });
    log.success('Convex CLI available');
  } catch {
    log.warn('Convex not installed globally. Will use npx.');
  }

  return !hasErrors;
}

async function setupConvex() {
  log.step(2, 'Setting up Convex...');

  const hasConvexJson = existsSync(join(ROOT_DIR, 'convex.json'));

  if (hasConvexJson) {
    log.info('Convex project already initialized');
    const reconfigure = await promptYesNo('Reconfigure Convex?', false);
    if (!reconfigure) return null;
  }

  console.log('\nStarting Convex dev server to get deployment URL...');
  console.log('(Press Ctrl+C after you see the deployment URL)\n');

  // Run convex dev
  try {
    execSync('npx convex dev --once', { stdio: 'inherit', cwd: ROOT_DIR });
  } catch {
    // User may have Ctrl+C'd
  }

  // Get deployment URL
  let deploymentUrl = '';
  try {
    const convexJson = JSON.parse(readFileSync(join(ROOT_DIR, '.convex.json'), 'utf-8'));
    deploymentUrl = `https://${convexJson.project}.convex.site`;
  } catch {
    deploymentUrl = await prompt('\nEnter your Convex deployment URL (e.g., https://your-project-123.convex.site): ');
  }

  log.success(`Convex deployment URL: ${deploymentUrl}`);
  return deploymentUrl;
}

async function setupSalesforce(convexUrl) {
  log.step(3, 'Setting up Salesforce...');

  // Check for authenticated org
  let orgAlias = '';
  try {
    const orgs = JSON.parse(execSync('sf org list --json', { encoding: 'utf-8' }));
    const connectedOrgs = orgs.result?.nonScratchOrgs || [];

    if (connectedOrgs.length > 0) {
      console.log('\nConnected Salesforce orgs:');
      connectedOrgs.forEach((org, i) => {
        const marker = org.isDefaultUsername ? '(default)' : '';
        console.log(`  ${i + 1}. ${org.alias || org.username} ${marker}`);
      });

      const useExisting = await promptYesNo('\nUse an existing org?', true);
      if (useExisting) {
        const choice = await prompt('Enter org number or alias: ');
        const idx = parseInt(choice) - 1;
        if (idx >= 0 && idx < connectedOrgs.length) {
          orgAlias = connectedOrgs[idx].alias || connectedOrgs[idx].username;
        } else {
          orgAlias = choice;
        }
      }
    }
  } catch {
    log.warn('Could not list orgs');
  }

  if (!orgAlias) {
    console.log('\nLet\'s authenticate with your Salesforce org...');
    orgAlias = await prompt('Enter an alias for this org: ');

    try {
      execSync(`sf org login web -a ${orgAlias}`, { stdio: 'inherit' });
    } catch {
      log.error('Authentication failed');
      return null;
    }
  }

  log.success(`Using Salesforce org: ${orgAlias}`);
  return orgAlias;
}

async function selectObjects() {
  log.step(4, 'Select objects to sync...');

  const selected = await promptSelect(
    'Which objects do you want to sync? (These must have CDC enabled in Salesforce)',
    STANDARD_OBJECTS
  );

  // Ask for custom objects
  const hasCustom = await promptYesNo('\nDo you have custom objects to sync?', false);
  if (hasCustom) {
    console.log('Enter custom object API names (one per line, empty line to finish):');
    let customObj = await prompt('> ');
    while (customObj) {
      if (!customObj.endsWith('__c')) customObj += '__c';
      selected.push(customObj);
      customObj = await prompt('> ');
    }
  }

  log.success(`Selected objects: ${selected.join(', ')}`);
  return selected;
}

function updateApexWebhookUrl(convexUrl) {
  log.step(5, 'Updating Apex webhook URL...');

  const apexPath = join(ROOT_DIR, 'salesforce/force-app/main/default/classes/ConvexCDCService.cls');
  let apexContent = readFileSync(apexPath, 'utf-8');

  const webhookUrl = `${convexUrl}/webhooks/salesforce/cdc`;
  apexContent = apexContent.replace(
    /private static final String CONVEX_WEBHOOK_URL = '[^']*'/,
    `private static final String CONVEX_WEBHOOK_URL = '${webhookUrl}'`
  );

  writeFileSync(apexPath, apexContent);
  log.success(`Updated webhook URL to: ${webhookUrl}`);
}

function generateTriggers(objects) {
  log.step(6, 'Generating CDC triggers...');

  const triggerDir = join(ROOT_DIR, 'salesforce/force-app/main/default/triggers');

  for (const obj of objects) {
    const triggerName = `${obj.replace('__c', '')}CDCTrigger`;
    const eventName = `${obj.replace('__c', '__')}ChangeEvent`;

    // Check if trigger already exists
    const triggerPath = join(triggerDir, `${triggerName}.trigger`);
    if (existsSync(triggerPath)) {
      log.info(`Trigger already exists: ${triggerName}`);
      continue;
    }

    // Generate trigger
    const triggerContent = `/**
 * CDC Trigger for ${obj} object
 * Auto-generated by setup wizard
 */
trigger ${triggerName} on ${eventName} (after insert) {
    ConvexCDCService.processChangeEvents(Trigger.new, '${obj}');
}
`;

    const metaContent = `<?xml version="1.0" encoding="UTF-8"?>
<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <status>Active</status>
</ApexTrigger>
`;

    writeFileSync(triggerPath, triggerContent);
    writeFileSync(`${triggerPath}-meta.xml`, metaContent);
    log.success(`Generated trigger: ${triggerName}`);
  }
}

async function deploySalesforce(orgAlias) {
  log.step(7, 'Deploying to Salesforce...');

  const deploy = await promptYesNo('Deploy to Salesforce now?', true);
  if (!deploy) {
    log.info('Skipping deployment. Run manually: npm run deploy:salesforce');
    return;
  }

  console.log('\nDeploying CDC triggers and service...');
  try {
    execSync(`sf project deploy start -d salesforce/force-app -o ${orgAlias}`, {
      stdio: 'inherit',
      cwd: ROOT_DIR,
    });
    log.success('Deployment successful!');
  } catch {
    log.error('Deployment failed. Check the errors above.');
    return false;
  }

  return true;
}

async function enableCDC(orgAlias, objects) {
  log.step(8, 'Enable CDC in Salesforce...');

  console.log(`
${colors.yellow}IMPORTANT: You need to enable CDC for your selected objects in Salesforce Setup.${colors.reset}

1. Go to Setup in Salesforce
2. Search for "Change Data Capture"
3. Select these objects:
${objects.map(o => `   - ${o}`).join('\n')}
4. Save
`);

  await prompt('Press Enter when you\'ve enabled CDC...');
  log.success('CDC configuration noted');
}

async function createEnvFile() {
  log.step(9, 'Creating environment file...');

  const envPath = join(ROOT_DIR, '.env.local');

  if (existsSync(envPath)) {
    const overwrite = await promptYesNo('.env.local already exists. Overwrite?', false);
    if (!overwrite) return;
  }

  console.log('\nEnter your Salesforce credentials (for Convex to call Salesforce API):');
  const instanceUrl = await prompt('Salesforce Instance URL (e.g., https://your-org.my.salesforce.com): ');
  const accessToken = await prompt('Salesforce Access Token (from session or connected app): ');

  const envContent = `# Salesforce API credentials
SALESFORCE_INSTANCE_URL=${instanceUrl}
SALESFORCE_ACCESS_TOKEN=${accessToken}
`;

  writeFileSync(envPath, envContent);
  log.success('Created .env.local');
  log.warn('Remember to add .env.local to .gitignore!');
}

async function runInitialSync() {
  log.step(10, 'Initial sync...');

  const sync = await promptYesNo('Run initial sync from Salesforce to Convex?', true);
  if (!sync) {
    log.info('Skipping initial sync. Run manually: npm run sync');
    return;
  }

  console.log('\nSyncing existing records...');
  try {
    execSync('npx convex run salesforce:syncAll', { stdio: 'inherit', cwd: ROOT_DIR });
    log.success('Initial sync complete!');
  } catch {
    log.warn('Sync had issues. Check the output above.');
  }
}

function printSummary(convexUrl, orgAlias, objects) {
  console.log(`
${colors.green}${colors.bright}
╔════════════════════════════════════════════════════════════════╗
║                    Setup Complete! 🎉                          ║
╚════════════════════════════════════════════════════════════════╝
${colors.reset}

${colors.cyan}Configuration Summary:${colors.reset}
  Convex URL:    ${convexUrl}
  Salesforce:    ${orgAlias}
  Objects:       ${objects.join(', ')}

${colors.cyan}Webhook URL:${colors.reset}
  ${convexUrl}/webhooks/salesforce/cdc

${colors.cyan}Next Steps:${colors.reset}
  1. Verify CDC is enabled in Salesforce Setup
  2. Make a change in Salesforce to test sync
  3. Check sync status: npm run status

${colors.cyan}Useful Commands:${colors.reset}
  npm run dev              - Start Convex dev server
  npm run sync             - Full sync from Salesforce
  npm run status           - Check sync statistics
  npm run deploy:salesforce - Deploy changes to Salesforce

${colors.cyan}Documentation:${colors.reset}
  https://github.com/yourusername/convex-salesforce-connector
`);
}

async function main() {
  console.log(`
${colors.cyan}${colors.bright}
╔════════════════════════════════════════════════════════════════╗
║     Convex Salesforce Connector - Setup Wizard                 ║
╚════════════════════════════════════════════════════════════════╝
${colors.reset}
This wizard will help you configure real-time sync between
Salesforce and Convex using Change Data Capture.
`);

  // Check prerequisites
  if (!checkPrerequisites()) {
    log.error('\nPlease install missing prerequisites and run again.');
    process.exit(1);
  }

  // Setup Convex
  const convexUrl = await setupConvex();
  if (!convexUrl) {
    log.error('Convex setup failed');
    process.exit(1);
  }

  // Setup Salesforce
  const orgAlias = await setupSalesforce(convexUrl);
  if (!orgAlias) {
    log.error('Salesforce setup failed');
    process.exit(1);
  }

  // Select objects
  const objects = await selectObjects();
  if (objects.length === 0) {
    log.error('No objects selected');
    process.exit(1);
  }

  // Update Apex webhook URL
  updateApexWebhookUrl(convexUrl);

  // Generate triggers
  generateTriggers(objects);

  // Deploy to Salesforce
  await deploySalesforce(orgAlias);

  // Guide through CDC enablement
  await enableCDC(orgAlias, objects);

  // Create env file
  await createEnvFile();

  // Initial sync
  await runInitialSync();

  // Print summary
  printSummary(convexUrl, orgAlias, objects);
}

main().catch((err) => {
  log.error(`Setup failed: ${err.message}`);
  process.exit(1);
});
