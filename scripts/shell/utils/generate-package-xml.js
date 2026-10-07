#!/usr/bin/env node

/**
 * Generate Package XML Script
 *
 * Purpose: Generates chunked package.xml files from metadata discovery output
 * Usage: node generate-package-xml.js [--input metadata-types.json] [--output-dir ./manifests]
 */

const fs = require('fs');
const path = require('path');

/**
 * Escape XML special characters for safe inclusion in XML documents
 * @param {string} str - String to escape
 * @returns {string} - XML-safe string
 */
function escapeXml(str) {
  if (!str) return str;
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// Load metadata configuration
const metadataConfig = require('./metadata-config.json');

/**
 * API version for generated manifests: API_VERSION env var, else sourceApiVersion from sfdx-project.json in the
 * working directory, else 61.0.
 * @returns {string}
 */
function resolveApiVersion() {
  if (process.env.API_VERSION) return process.env.API_VERSION;
  try {
    const project = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'sfdx-project.json'), 'utf8'));
    if (project.sourceApiVersion) return project.sourceApiVersion;
  } catch (e) {
    // fall through to the default
  }
  return '61.0';
}

const API_VERSION = resolveApiVersion();

/**
 * Filter out unsupported metadata types based on configuration
 * @param {Array} metadataTypes - Array of metadata type objects
 * @returns {Object} - Object with filtered and excluded arrays
 */
function filterUnsupportedTypes(metadataTypes) {
  const config = metadataConfig;
  const filtered = metadataTypes.filter(type => !config.unsupportedTypes.includes(type.xmlName));

  const excluded = metadataTypes.filter(type => config.unsupportedTypes.includes(type.xmlName));

  if (excluded.length > 0) {
    console.log(`⚠ Excluded unsupported metadata types: ${excluded.map(t => t.xmlName).join(', ')}`);
  }

  return { filtered, excluded };
}

/**
 * Reload metadata configuration (useful for dynamic updates during retry logic)
 * @returns {Object} - Fresh metadata configuration
 */
function reloadMetadataConfig() {
  // Clear the require cache to get fresh config
  delete require.cache[require.resolve('./metadata-config.json')];
  return require('./metadata-config.json');
}

/**
 * Filter metadata types with dynamic exclusions (Phase 2 compatibility)
 * This function supports runtime exclusion of additional metadata types
 * @param {Array} metadataTypes - Array of metadata type objects
 * @param {Array} additionalExclusions - Additional types to exclude
 * @returns {Object} - Object with filtered and excluded arrays
 */
function filterWithDynamicExclusions(metadataTypes, additionalExclusions = []) {
  const config = reloadMetadataConfig();
  const allExclusions = [...config.unsupportedTypes, ...additionalExclusions];

  const filtered = metadataTypes.filter(type => !allExclusions.includes(type.xmlName));
  const excluded = metadataTypes.filter(type => allExclusions.includes(type.xmlName));

  if (excluded.length > 0) {
    console.log(`⚠ Excluded metadata types: ${excluded.map(t => t.xmlName).join(', ')}`);
    if (additionalExclusions.length > 0) {
      console.log(`  (Including ${additionalExclusions.length} dynamic exclusions)`);
    }
  }

  return { filtered, excluded };
}

// Configuration for chunking metadata types
const CHUNKS = {
  code: {
    name: 'Code Components',
    types: [
      'ApexClass',
      'ApexTrigger',
      'ApexComponent',
      'ApexPage',
      'AuraDefinitionBundle',
      'LightningComponentBundle',
      'StaticResource',
    ],
  },
  objects: {
    name: 'Objects & Fields',
    types: [
      'CustomObject',
      'CustomField',
      'RecordType',
      'ListView',
      'ValidationRule',
      'BusinessProcess',
      'CompactLayout',
      'FieldSet',
      'WebLink',
      'CustomObjectTranslation',
    ],
  },
  configuration: {
    name: 'Configuration',
    types: [
      'CustomMetadata',
      'CustomSettings',
      'CustomLabels',
      'GlobalValueSet',
      'StandardValueSet',
      'Translations',
      'GlobalPicklist',
    ],
  },
  automation: {
    name: 'Automation',
    types: [
      'Flow',
      'Workflow',
      'WorkflowRule',
      'WorkflowAlert',
      'WorkflowFieldUpdate',
      'WorkflowTask',
      'ProcessBuilder',
      'ApprovalProcess',
      'AutomatedContactRequest',
      'EmailServicesFunction',
      'AssignmentRules',
    ],
  },
  ui: {
    name: 'UI Components',
    types: [
      'Layout',
      'FlexiPage',
      'CustomTab',
      'CustomApplication',
      'QuickAction',
      'LightningExperienceTheme',
      'AppMenu',
      'CustomApplicationComponent',
    ],
  },
  security: {
    name: 'Security',
    // Note: Profiles and Permission Sets need special handling
    types: ['PermissionSet', 'PermissionSetGroup', 'Role', 'Group', 'DuplicateRule', 'MatchingRules'],
  },
  settings: {
    name: 'Settings',
    types: [
      'AccountSettings',
      'ActivitiesSettings',
      'AddressSettings',
      'CaseSettings',
      'ChatterAnswersSettings',
      'CompanySettings',
      'ContractSettings',
      'EntitlementSettings',
      'FieldServiceSettings',
      'FileUploadAndDownloadSecuritySettings',
      'ForecastingSettings',
      'IdeasSettings',
      'IoTSettings',
      'KnowledgeSettings',
      'LanguageSettings',
      'LeadConfigSettings',
      'LiveAgentSettings',
      'MacroSettings',
      'MobileSettings',
      'NameSettings',
      'OpportunitySettings',
      'OrderSettings',
      'OrgPreferenceSettings',
      'PathAssistantSettings',
      'ProductSettings',
      'QuoteSettings',
      'SearchSettings',
      'SecuritySettings',
      'SharingSettings',
      'SiteSettings',
      'SocialCustomerServiceSettings',
      'TerritorySettings',
    ],
  },
  sharing: {
    name: 'Sharing Rules',
    types: ['SharingRules', 'SharingCriteriaRule', 'SharingOwnerRule', 'SharingTerritoryRule'],
  },
  reports: {
    name: 'Reports & Dashboards',
    types: ['Report', 'Dashboard', 'ReportType', 'DashboardFolder', 'ReportFolder'],
  },
  email: {
    name: 'Email Configuration',
    types: ['EmailTemplate', 'EmailFolder', 'Letterhead', 'BrandTemplate'],
  },
};

// Metadata types to exclude from wildcard retrieval
const EXCLUDE_FROM_WILDCARD = [
  'Profile', // Retrieve only specific profiles
  'Document', // Large binary files
  'ContentAsset', // Large binary files
  'InstalledPackage', // Handled separately
  'StandardValueSet', // Must be explicitly named
];

// Problematic metadata types that often fail
const PROBLEMATIC_TYPES = [
  'CustomObjectTranslation',
  'Translations',
  'DataCategoryGroup',
  'Territory',
  'Territory2',
  'mktdatalakesrckeyqualifier', // Unsupported Marketing Data Lake type (lowercase)
  'MktDatalakeSrcKeyQualifier', // Unsupported Marketing Data Lake type (Pascal case)
  'externalauthidentityprovider', // Unsupported external auth type (lowercase)
  'ExternalAuthIdentityProvider', // Unsupported external auth type (Pascal case)
  'uiformatspecificationset', // Unsupported UI format type (lowercase)
  'UiFormatSpecificationSet', // Unsupported UI format type (Pascal case)
  'oauthtokenexchangehandler', // Unsupported OAuth token type (lowercase)
  'OauthTokenExchangeHandler', // Unsupported OAuth token type (Pascal case)
  'extlclntappconfigurablepolicies', // Unsupported external client app type (lowercase)
  'ExtlClntAppConfigurablePolicies', // Unsupported external client app type (Pascal case)
  'extlclntappsamlconfigurablepolicies', // Unsupported external client SAML type (lowercase)
  'ExtlClntAppSamlConfigurablePolicies', // Unsupported external client SAML type (Pascal case)
  'extlclntapppushsettings', // Unsupported external client push settings (lowercase)
  'ExtlClntAppPushSettings', // Unsupported external client push settings (Pascal case)
];

function parseArguments() {
  const args = process.argv.slice(2);

  // Get project root directory
  const projectRoot = path.resolve(__dirname, '../../..');

  const options = {
    input: 'metadata-types.json',
    outputDir: './manifests',
    includeProblematic: false,
    logsDir: path.join(projectRoot, 'logs'),
  };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--input' && args[i + 1]) {
      options.input = args[i + 1];
      i++;
    } else if (args[i] === '--output-dir' && args[i + 1]) {
      options.outputDir = args[i + 1];
      i++;
    } else if (args[i] === '--logs-dir' && args[i + 1]) {
      options.logsDir = args[i + 1];
      i++;
    } else if (args[i] === '--include-problematic') {
      options.includeProblematic = true;
    }
  }

  return options;
}

function loadMetadataTypes(inputFile) {
  try {
    const data = fs.readFileSync(inputFile, 'utf8');
    const json = JSON.parse(data);
    return json.result.metadataObjects;
  } catch (error) {
    console.error(`Error loading metadata types from ${inputFile}:`, error.message);
    process.exit(1);
  }
}

function categorizeMetadataType(typeName, allTypes) {
  // Check if it's excluded
  if (EXCLUDE_FROM_WILDCARD.includes(typeName)) {
    return 'excluded';
  }

  // Check if it's problematic (unless explicitly included)
  if (!options.includeProblematic && PROBLEMATIC_TYPES.includes(typeName)) {
    return 'problematic';
  }

  // Find which chunk it belongs to
  for (const [chunkName, chunk] of Object.entries(CHUNKS)) {
    if (chunk.types.includes(typeName)) {
      return chunkName;
    }
  }

  // Default to 'other' chunk
  return 'other';
}

function generatePackageXml(metadataTypes, chunkName, chunkDescription) {
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n';
  xml += `    <!-- ${chunkDescription} -->\n`;

  for (const type of metadataTypes) {
    xml += '    <types>\n';

    // Special handling for certain types
    if (type.xmlName === 'StandardValueSet') {
      // StandardValueSet needs explicit members
      xml += '        <!-- StandardValueSet requires explicit member names -->\n';
      xml += '        <!-- Add specific StandardValueSet names here -->\n';
      // Common standard value sets
      const commonValueSets = [
        'AccountContactMultiRoles',
        'AccountContactRole',
        'AccountOwnership',
        'AccountRating',
        'AccountType',
        'CaseContactRole',
        'CaseOrigin',
        'CasePriority',
        'CaseReason',
        'CaseStatus',
        'CaseType',
        'ContactRole',
        'EntitlementType',
        'LeadSource',
        'LeadStatus',
        'OpportunityCompetitor',
        'OpportunityStage',
        'OpportunityType',
        'PartnerRole',
        'Product2Family',
        'SalesTeamRole',
        'SocialPostClassification',
        'SocialPostEngagementLevel',
        'SolutionStatus',
        'TaskPriority',
        'TaskStatus',
        'TaskSubject',
        'TaskType',
      ];
      for (const valueSet of commonValueSets) {
        xml += `        <members>${escapeXml(valueSet)}</members>\n`;
      }
    } else if (type.xmlName === 'LightningComponentBundle') {
      // LightningComponentBundle doesn't support wildcards - use explicit members
      if (type.members && type.members.length > 0) {
        xml += '        <!-- Explicit LWC members (wildcard not supported) -->\n';
        console.log(`  Adding ${type.members.length} explicit LWC members to package.xml`);

        for (const member of type.members) {
          const memberName = member.fullName || member;
          xml += `        <members>${escapeXml(memberName)}</members>\n`;
        }
      } else {
        // Warning if no members found
        console.warn('  ⚠ WARNING: No LWC members found - retrieval will fail');
        xml += '        <!-- WARNING: No LWC members found - wildcard not supported -->\n';
        xml += '        <!-- LWCs must be explicitly listed for retrieval -->\n';
      }
    } else if (type.xmlName === 'CustomObject' && chunkName === 'objects') {
      // Use discovered objects if available, otherwise fallback to config
      if (type.members && type.members.length > 0) {
        xml += '        <!-- Using all objects discovered from org -->\n';

        const standardObjects = type.members.filter(member => !member.fullName.endsWith('__c'));
        const customObjects = type.members.filter(member => member.fullName.endsWith('__c'));

        // Add all discovered standard objects explicitly
        for (const stdObj of standardObjects) {
          xml += `        <members>${escapeXml(stdObj.fullName)}</members>\n`;
        }

        // Add all discovered custom objects explicitly
        for (const custObj of customObjects) {
          xml += `        <members>${escapeXml(custObj.fullName)}</members>\n`;
        }

        console.log(
          `  ✓ Added ${standardObjects.length} standard objects and ${customObjects.length} custom objects from discovery`,
        );
      } else {
        // Fallback to existing configuration-based approach
        const config = reloadMetadataConfig();

        if (config.standardObjects && config.standardObjects.enabled) {
          xml += '        <!-- Explicitly including standard objects to ensure retrieval -->\n';
          xml += `        <!-- Reason: ${config.standardObjects.reason} -->\n`;

          // Add standard objects explicitly from config
          for (const stdObj of config.standardObjects.explicitList) {
            xml += `        <members>${escapeXml(stdObj)}</members>\n`;
          }

          // Also include all custom objects with wildcard
          xml += '        <members>*</members>\n';
          xml += '        <!-- Custom objects included via wildcard above -->\n';

          console.log(
            `  ⚠ Fallback: Added ${config.standardObjects.explicitList.length} explicit standard objects from config`,
          );
        } else {
          // Final fallback to wildcard only if standard objects disabled
          xml += '        <members>*</members>\n';
          xml += '        <!-- Standard objects disabled in config -->\n';
        }
      }
    } else if (type.xmlName === 'Report' && chunkName === 'reports') {
      // Report doesn't support wildcards for folder-based metadata - use explicit members from SOQL discovery
      if (type.members && type.members.length > 0) {
        xml +=
          '        <!-- Explicit Report members from SOQL discovery (wildcard not supported for folder-based metadata) -->\n';
        console.log(`  Adding ${type.members.length} explicit Report members to package.xml`);

        for (const member of type.members) {
          const memberName = member.fullName || member;
          xml += `        <members>${escapeXml(memberName)}</members>\n`;
        }
      } else {
        // Warning if no members found
        console.warn('  ⚠ WARNING: No Report members found - retrieval will only get unfiled reports');
        xml += '        <!-- WARNING: No Report members found via SOQL discovery -->\n';
        xml += '        <!-- Reports must be explicitly listed for proper retrieval of folder-based reports -->\n';
        xml += '        <members>*</members>\n';
        xml += '        <!-- Wildcard will only retrieve unfiled reports, not folder-based ones -->\n';
      }
    } else if (type.xmlName === 'Dashboard' && chunkName === 'reports') {
      // Dashboard doesn't support wildcards for folder-based metadata - use explicit members from SOQL discovery
      if (type.members && type.members.length > 0) {
        xml +=
          '        <!-- Explicit Dashboard members from SOQL discovery (wildcard not supported for folder-based metadata) -->\n';
        console.log(`  Adding ${type.members.length} explicit Dashboard members to package.xml`);

        for (const member of type.members) {
          const memberName = member.fullName || member;
          xml += `        <members>${escapeXml(memberName)}</members>\n`;
        }
      } else {
        // Warning if no members found
        console.warn('  ⚠ WARNING: No Dashboard members found - retrieval will only get unfiled dashboards');
        xml += '        <!-- WARNING: No Dashboard members found via SOQL discovery -->\n';
        xml +=
          '        <!-- Dashboards must be explicitly listed for proper retrieval of folder-based dashboards -->\n';
        xml += '        <members>*</members>\n';
        xml += '        <!-- Wildcard will only retrieve unfiled dashboards, not folder-based ones -->\n';
      }
    } else if (type.xmlName === 'Profile' && chunkName === 'security') {
      // Only retrieve specific profiles, not all
      xml += '        <!-- Retrieving only custom profiles to avoid large files -->\n';
      xml += '        <members>*</members>\n';
      xml += '        <!-- Consider listing specific profiles instead of wildcard -->\n';
    } else {
      // Use wildcard for most types
      xml += '        <members>*</members>\n';
    }

    xml += `        <name>${type.xmlName}</name>\n`;
    xml += '    </types>\n';
  }

  xml += `    <version>${API_VERSION}</version>\n`;
  xml += '</Package>';

  return xml;
}

function generateSpecialPackageXml(purpose, items) {
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n';
  xml += `    <!-- ${purpose} -->\n`;

  if (purpose === 'Selected Profiles') {
    xml += '    <types>\n';
    for (const profile of items) {
      xml += `        <members>${profile}</members>\n`;
    }
    xml += '        <name>Profile</name>\n';
    xml += '    </types>\n';
  }

  xml += `    <version>${API_VERSION}</version>\n`;
  xml += '</Package>';

  return xml;
}

function validateLWCInclusion(metadataTypes) {
  const lwcType = metadataTypes.find(t => t.xmlName === 'LightningComponentBundle');

  if (lwcType) {
    if (!lwcType.members || lwcType.members.length === 0) {
      console.error('ERROR: No LWC members found for inclusion');
      console.error('This will result in zero LWCs being retrieved');
      process.exit(1);
    }
    console.log(`✓ Validated: ${lwcType.members.length} LWCs will be retrieved`);
  } else {
    console.log('ℹ No LightningComponentBundle metadata type found in discovery');
  }
}

// Main execution
const options = parseArguments();

// Create logs directory
if (!fs.existsSync(options.logsDir)) {
  fs.mkdirSync(options.logsDir, { recursive: true });
}

// Set up logging
const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
const logFile = path.join(options.logsDir, `package-xml-generation-${timestamp}.log`);

function logWithTimestamp(message) {
  const timestampedMessage = `[${new Date().toISOString()}] ${message}`;
  console.log(message);
  fs.appendFileSync(logFile, timestampedMessage + '\n');
}

logWithTimestamp('=================================================================');
logWithTimestamp('Package XML Generator');
logWithTimestamp('=================================================================');
logWithTimestamp(`Input file: ${options.input}`);
logWithTimestamp(`Output directory: ${options.outputDir}`);
logWithTimestamp(`Logs directory: ${options.logsDir}`);
logWithTimestamp(`Include problematic types: ${options.includeProblematic}`);
logWithTimestamp('');

// Create output directory if it doesn't exist
if (!fs.existsSync(options.outputDir)) {
  fs.mkdirSync(options.outputDir, { recursive: true });
  console.log(`Created output directory: ${options.outputDir}`);
}

// Load metadata types
const rawMetadataTypes = loadMetadataTypes(options.input);
logWithTimestamp(`Loaded ${rawMetadataTypes.length} metadata types`);

// Filter out unsupported types (using dynamic filtering for Phase 2 compatibility)
const { filtered: metadataTypes, excluded: excludedTypes } = filterWithDynamicExclusions(rawMetadataTypes);
logWithTimestamp(`Filtered out ${excludedTypes.length} unsupported types, processing ${metadataTypes.length} types`);

// Validate LWC inclusion
validateLWCInclusion(metadataTypes);

// Categorize metadata types
const categorized = {
  code: [],
  objects: [],
  configuration: [],
  automation: [],
  ui: [],
  security: [],
  settings: [],
  sharing: [],
  reports: [],
  email: [],
  other: [],
  excluded: [],
  problematic: [],
};

for (const type of metadataTypes) {
  const category = categorizeMetadataType(type.xmlName, metadataTypes);
  categorized[category].push(type);
}

// Generate package.xml files for each chunk
logWithTimestamp('\nGenerating package.xml files:');
for (const [chunkName, types] of Object.entries(categorized)) {
  if (types.length === 0 || chunkName === 'excluded' || chunkName === 'problematic') {
    continue;
  }

  const description = CHUNKS[chunkName]?.name || 'Other Metadata Types';
  const filename = path.join(options.outputDir, `package-${chunkName}.xml`);
  const xml = generatePackageXml(types, chunkName, description);

  fs.writeFileSync(filename, xml);
  logWithTimestamp(`  ✓ ${filename} (${types.length} types)`);
}

// Generate special package.xml for selected profiles
const profilesFilename = path.join(options.outputDir, 'package-profiles.xml');
const selectedProfiles = [
  'Admin',
  'Custom%', // All custom profiles
  '*Support*', // Profiles with 'Support' in the name
];
const profilesXml = generateSpecialPackageXml('Selected Profiles', selectedProfiles);
fs.writeFileSync(profilesFilename, profilesXml);
logWithTimestamp(`  ✓ ${profilesFilename} (selected profiles only)`);

// Write summary report
const summaryFilename = path.join(options.logsDir, `metadata-summary-${timestamp}.txt`);
let summary = 'Metadata Type Summary\n';
summary += '=====================\n';
summary += `Generated: ${new Date().toISOString()}\n`;
summary += `Input file: ${options.input}\n`;
summary += `Output directory: ${options.outputDir}\n\n`;

for (const [category, types] of Object.entries(categorized)) {
  summary += `${category.toUpperCase()} (${types.length} types)\n`;
  summary += '-'.repeat(30) + '\n';
  for (const type of types) {
    summary += `  - ${type.xmlName}\n`;
  }
  summary += '\n';
}

// Add excluded types to summary
if (excludedTypes.length > 0) {
  summary += `EXCLUDED UNSUPPORTED TYPES (${excludedTypes.length} types)\n`;
  summary += '-'.repeat(30) + '\n';
  for (const type of excludedTypes) {
    summary += `  - ${type.xmlName} (unsupported by Metadata API)\n`;
  }
  summary += '\n';
}

fs.writeFileSync(summaryFilename, summary);
logWithTimestamp(`\n✓ Summary written to: ${summaryFilename}`);

// Display warnings
if (excludedTypes.length > 0) {
  logWithTimestamp('\n⚠ Excluded unsupported metadata types (filtered out):');
  for (const type of excludedTypes) {
    logWithTimestamp(`  - ${type.xmlName} (unsupported by Metadata API)`);
  }
}

if (categorized.excluded.length > 0) {
  logWithTimestamp('\n⚠ Excluded metadata types (require special handling):');
  for (const type of categorized.excluded) {
    logWithTimestamp(`  - ${type.xmlName}`);
  }
}

if (categorized.problematic.length > 0) {
  logWithTimestamp('\n⚠ Problematic metadata types (often fail, excluded by default):');
  for (const type of categorized.problematic) {
    logWithTimestamp(`  - ${type.xmlName}`);
  }
  logWithTimestamp('  Use --include-problematic to include these types');
}

logWithTimestamp('\n✓ Package XML generation complete!');
logWithTimestamp(`Log file: ${logFile}`);
logWithTimestamp('Next step: Run retrieve-all-metadata.sh to retrieve the metadata');
