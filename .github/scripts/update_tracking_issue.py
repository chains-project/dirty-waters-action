#!/usr/bin/env python3
import os
import re
from github import Github, Issue
import datetime

def main():
    github_token = os.environ["GITHUB_TOKEN"]
    workflow_path = os.environ["WORKFLOW_PATH"]
    issue_title = os.environ["ISSUE_TITLE"]
    source_repo_name = os.environ["SOURCE_REPO"]
    action_repo_name = os.environ["ACTION_REPO"]
    
    g = Github(github_token)
    source_repo = g.get_repo(source_repo_name)
    action_repo = g.get_repo(action_repo_name)
    
    tracking_issue = None
    for issue in action_repo.get_issues(state="open"):
        if issue.title == issue_title:
            tracking_issue = issue
            break
            
    if not tracking_issue:
        # Create new tracking issue if it doesn't exist
        tracking_issue = action_repo.create_issue(
            title=issue_title,
            body="# Check Dirty-Waters Updates\n`dirty-waters` has no unattended updates."
        )
        print(f"Created new tracking issue: #{tracking_issue.number}")
    else:
        print(f"Found existing tracking issue: #{tracking_issue.number}")
    
    # Get all tags from source repo
    tags = list(source_repo.get_tags())    
    already_processed_tags = []
    
    body_lines = tracking_issue.body.split('\n')
    has_unchecked_tags = False    
    for line in body_lines:
        # Look for tags that are being tracked but not checked yet
        if match := re.match(r'- \[ \] (v\d+\.\d+\.\d+)', line):
            already_processed_tags.append(match.group(1))
            has_unchecked_tags = True
    
    # If there are no unchecked tags, we'll only look for tags since the last workflow run
    if not has_unchecked_tags:
        # Get the timestamp of the last workflow run
        # For the first run or when the GitHub Actions API doesn't have 
        # a stored run, default to 24 hours ago
        last_run_time = datetime.datetime.now() - datetime.timedelta(hours=24)
        
        # Try to get the last workflow run time
        try:
            workflow_runs = action_repo.get_workflow_runs()
            for run in workflow_runs:
                if run.name == workflow_path:
                    last_run_time = run.created_at
                    break
            print(f"Last successful workflow run was at: {last_run_time}")
        except Exception as e:
            print(f"Error getting last workflow run time: {e}")
            print("Using default time period of 24 hours")
    
        # Get new tags only since the last run
        new_tags = []
        for tag in tags:
            tag_name = tag.name
            # Get the tag creation time
            try:
                tag_commit = source_repo.get_commit(tag.commit.sha)
                tag_time = tag_commit.commit.author.date
                
                if (
                    tag_time > last_run_time and
                    tag_name not in already_processed_tags and
                    tag_name.startswith('v')  # Only consider version tags
                ):
                    new_tags.append(f"[{tag_name}]({tag.commit.html_url})")
            except Exception as e:
                print(f"Error processing tag {tag_name}: {e}")
    else:
        # Get all new tags that aren't already in the issue
        new_tags = []
        for tag in tags:
            tag_name = tag.name
            if (
                tag_name not in already_processed_tags and
                tag_name.startswith('v')  # Only consider version tags
            ):
                new_tags.append(f"[{tag_name}]({tag.commit.html_url})")
    
    # If there are new tags, update the issue
    if new_tags:
        # Build the list of all unchecked tags (both existing and new)
        combined_unchecked = already_processed_tags + new_tags
        print(f"Found {len(new_tags)} new tags to process")
        count = len(combined_unchecked)
        plural = "s" if count > 1 else ""
        
        new_body = f"# Check Dirty-Waters Updates\n`dirty-waters` has {count} new tag{plural} with updates to be attended to:\n"
        for tag in combined_unchecked:
            print(f"Adding tag: {tag}")
            new_body += f"- [ ] {tag}\n"
        
        # Update the issue body
        tracking_issue.edit(body=new_body)
        print(f"Updated tracking issue with {len(new_tags)} new tags")
    elif not already_processed_tags:
        # No updates to attend to, and no existing unchecked tags
        new_body = "# Check Dirty-Waters Updates\n`dirty-waters` has no unattended updates."
        tracking_issue.edit(body=new_body)
        print("Updated issue: no updates to attend to")

if __name__ == "__main__":
    main()