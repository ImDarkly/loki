---
name: create-issue
description: Create a GitHub issue with this repository's required metadata, native relationships, and read-back verification.
---

# Create GitHub Issue

Use this skill whenever creating a GitHub issue for this repository. Do not create an issue until the user has authorized it.

## Pull requests and issues (always)

- Every PR implements exactly one issue. Don't open a PR without an issue. If none exists, create it first with the create-issue skill.
- Put "Fixes #N" in the PR description so GitHub links it and closes the issue on merge. If the PR only partly resolves it, use "Refs #N" instead and say what's left.
- Name the branch with the issue number, e.g. feature/123-short-name.
- Use the same labels and milestone as the issue, and add the PR to the same project board.
- If the issue has a parent or is blocked by another, don't start work until the blocker is merged. Say so if it isn't.
- After opening the PR, read it back and confirm the issue link shows on the PR and the issue.

1. Resolve the repository instead of guessing it:

   ```powershell
   $repo = gh repo view --json nameWithOwner --jq .nameWithOwner
   $owner, $name = $repo -split '/', 2
   ```

2. List available labels and milestones before selecting either. Use only an existing label or milestone. If a requested one is absent, ask the user; do not create it.

   ```powershell
   gh label list --repo $repo --limit 100
   gh api "repos/$repo/milestones?state=all"
   ```

3. List projects for `$owner`. Add the issue to the project only when there is exactly one applicable existing project. If none exist, report that; if several could apply, ask the user which one.

   ```powershell
   gh project list --owner $owner
   ```

4. Prepare the issue with the exact title form `feat(scope): title` and these body sections in order: `What`, `Why`, `Source`, `Acceptance criteria`, and `Blocked by`. State `None` under `Blocked by` when there is no dependency. Create it with assignee `ImDarkly`, existing labels, and an existing milestone when selected. Capture the created issue number and URL.

5. Apply requested native relationships after creation. For a multi-issue creation sequence, use the `addBlockedBy` mutation required by `AGENTS.md`; resolve node IDs using the repository's actual owner and name:

   ```graphql
   query($owner: String!, $name: String!, $number: Int!) {
     repository(owner: $owner, name: $name) {
       issue(number: $number) { id }
     }
   }
   ```

   For an issue blocked by another issue, use `addBlockedBy` with the blocked issue as `issueId` and its blocker as `blockingIssueId`. For a blocking relationship, apply that mutation to the other issue with the new issue as `blockingIssueId`. For a sub-issue, resolve the child issue's database ID, then add it to the known parent number:

   ```powershell
   $child_issue_id = gh api "repos/$repo/issues/<child-number>" --jq .id
   gh api --method POST "repos/$repo/issues/<parent-number>/sub_issues" -F sub_issue_id=$child_issue_id
   ```

   If GitHub rejects a requested relation because of permissions, repository boundaries, or unavailable API support, say so clearly in the issue report.

   ```graphql
   mutation($issueId: ID!, $blockingIssueId: ID!) {
     addBlockedBy(input: {issueId: $issueId, blockingIssueId: $blockingIssueId}) {
       issue { id }
     }
   }
   ```

6. Add the created issue URL to the selected project, if one applies:

   ```powershell
   gh project item-add <project-number> --owner $owner --url <issue-url>
   ```

7. Read the issue back with `gh issue view <number> --repo $repo --json title,body,labels,milestone,assignees,projectItems,url`. Read dependencies with this GraphQL query and verify any hierarchy with `gh api "repos/$repo/issues/<number>/parent"` and `gh api "repos/$repo/issues/<number>/sub_issues"`:

   ```graphql
   query($owner: String!, $name: String!, $number: Int!) {
     repository(owner: $owner, name: $name) {
       issue(number: $number) {
         blockedBy(first: 100) { nodes { number url } }
         blocking(first: 100) { nodes { number url } }
       }
     }
   }
   ```

   Present a verification table with exactly these columns: `number`, `title`, `labels`, `milestone`, `relations`. Follow it with a completion checklist for the required body sections, assignee, and project. Correct omissions before reporting completion.
