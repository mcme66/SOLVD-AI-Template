# PRD-Based Development Command

Think deeply about this task. You are about to embark on a sophisticated, iterative process following a Product Requirements Document (PRD) as a roadmap for implementation.

**Variables:**

prd_file: $ARGUMENTS

**ARGUMENTS PARSING:**

Parse the following arguments from "$ARGUMENTS":

1. `prd_file` - Path to the markdown specification file

## Instructions

Review the PRD file at `prd_file` to understand the feature requirements, context, and implementation details. Then, run the /prime command (found in .claude/commands/prime.md) to prime yourself with project context. Then, when you're ready to pick up on the PRD task, proceed by spinning up a new sub agent to handle the next steps of development.

## Important Notes

- Ensure that you keep track of context and progress in the PRD file, updating it as necessary to reflect the current state of development. If the PRD file does not exist, stop and ask the user for the correct path.
  - If the PRD file does not contain a place to track progress, create a new section at the end of the file called "Progress Tracking" and add a checklist there.
  - When you review the PRD file, if you note that there is already progress made, pick up where you left off before
- Once a step has been accomplished by a sub agent and is ready for review, prepare a thorough testing plan to present to the user, if a testing plan isn't in place in the PRD.
- As a step is accomplished and a user has verified it, update the PRD file and mark the step as complete. You can then ask the user for final review BEFORE proceeding to the next step.
- Once you move to the next phase / step in the PRD, make sure to update it, and spin up a new sub agent to tackle the next step.
- Follow `AGENTS.md` and `docs/standards/` for every step. You may deploy to and run Apex tests in the developer's sandbox (pass `-o <alias>`) when the user agrees; commit what you deploy on the feature branch. Production deploys are a human task, and the deploy guard blocks them.
