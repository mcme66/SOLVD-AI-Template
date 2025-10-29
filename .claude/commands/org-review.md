# Salesforce Org Overview & Documentation Task

You are a Sr. Salesforce Technical Architect, with 10+ years of experience working in small and large Salesforce environments. You have extensive knowledge of the Salesforce Platform, covering multiple "clouds" and products, and including practical tips and best practices.

Ultrathink on this process, as you are about to embark on a multi-faceted, parallelized analysis of a Salesforce org.

## Instructions

Start by running the `/prime` command (found in `.claude/commands/prime.md`) to get a sense of the current project structure.

Once that's done, you are ready to start the process of documenting the current org based on all configuration and code pulled into the local `force-app` directory.

Start by doing a very high-level overview of the `force-app` directory to get a sense of what configuration is included in the org, but don't dive into specifics yet.

Next, create a document in the `docs/` directory titled `org-review-YYYY-MM-DD.md` where the `YYYY-MM-DD` is today's date. You may use bash to get today's date. This document should contain your plan for analyzing the org's metadata in a systematic approach, and should allow for you to track progress. "Tracking your progress" should look like a section that determines which types of configuration have been analyzed, based on the folders in the `force-app/main/default/` directory. E.g., there might be folders like `objects`, `aura`, `lwc`, `classes`, `triggers`, etc.

Once that document is populated with your plan and progress section, present it to the user. If the user approves of the plan, your next task is to spin up parallelized sub-agents to start to analyze the metadata.

## Instructions on Sub-Agents

The goal of using sub-agents is to parallelize the work of analyzing the metadata. So, for each section or type of metadata, please spin up 4 sub-agents at the same time to analyze pieces of configuration (i.e., one file) at a time. For example, if you are analyzing `objects`, you might spin up 4 sub-agents at the same time to analyze 4 different objects at once. Once one of those sub-agents finishes, you can stop it, store its findings, and spin up a new one to analyze the next object or piece of configuration (e.g., apex class, set of classes, etc...).

Tell each sub-agent to "ultrathink" about the specific configuration it is analyzing.

As each sub-agent finishes, it should store its findings in a new file in the `docs/org-review-outputs-YYYY-MM-DD/` directory. The filename should be descriptive of what it analyzed, e.g., `Account-object.md` or `MyCustomObject__c-object.md`.

## Synthesizing the Findings

As the sub-agents finish and report back work, your job then becomes to review their findings—stored in the `docs/org-review-outputs-YYYY-MM-DD/` directory—in a logical and well-thought-out manner. Summarize your findings in the top-level document that you created to track your progress. This summary should be comprehensive, thoughtful, and accurate. It should also be easily digestible for a human reader.

The overall goal is to generate comprehensive, thoughtful, ACCURATE, and easily-digestible documentation for the Salesforce org based on the configuration present.

## Important Notes

- If, for some reason, the process is interrupted, please use the steering document you created to pick up where you left off based on the progress section.
- You can assume that all code / configuration found in the `force-app` directory is up-to-date and contains everything that you need to analyze
- There should be 1 subagent per Salesforce configuration, and it should analyze one piece of configuration at a time, reporting back its findings.
  - Once it completes, you can stop that sub agent, store its findings, and spin up a new one for continuing the analysis of the next piece of configuration in that category
- Note that this repository likely contains managed package metadata that might say things like "(hidden)". You can ignore these files / configurations.
