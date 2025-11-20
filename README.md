# SOLVD Salesforce Project Base Template

> Built with ❤️&nbsp; by John

## Initial Steps

After cloning this repository down to your local machine, run the following commands to install the necessary dependencies:

```bash
nvm use
# Note that you might need to run `nvm install` first if you don't have the correct Node version installed
npm install
```

## Using the Metadata Retrieval Tool

1. Authenticate to your target Salesforce org by hitting `CMD + SHIFT + P` (Mac) or `CTRL + SHIFT + P` (Windows), then typing and selecting `SFDX: Authorize an Org`. Follow the prompts to complete the authentication process.

2. Run the following commands to retrieve metadata from your authenticated org:

**Important Note**: Run these commands in a separate terminal emulator, not the built-in terminal in VS Code, as it may not handle the output correctly, or it might crash.

```bash
npm run retrieve:all -- -o "YOUR_ORG_ALIAS"
```

## Original Notes from the SFDX Project Template

Now that you’ve created a Salesforce DX project, what’s next? Here are some documentation resources to get you started.

### How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

### Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

### Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
