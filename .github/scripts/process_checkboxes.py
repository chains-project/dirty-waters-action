#!/usr/bin/env python3
import os
import re
from github import Github
import json

def main():
    github_token = os.environ["GITHUB_TOKEN"]
    issue_title = os.environ["ISSUE_TITLE"]
    event_path = os.environ["GITHUB_EVENT_PATH"]
    
    with open(event_path, 'r') as f:
        event = json.load(f)
    
    # Check if this is our tracking issue
    if event["issue"]["title"] != issue_title:
        print(f"Not the tracking issue ({event['issue']['title']} != {issue_title}). Skipping.")
        return
    
    g = Github(github_token)
    repo = g.get_repo(event["repository"]["full_name"])
    issue = repo.get_issue(event["issue"]["number"])
    
    body = issue.body
    lines = body.split('\n')
    has_checked_items = False
    for line in lines:
        if re.match(r'- \[x\] v\d+\.\d+\.\d+', line):
            has_checked_items = True
            break
    
    if not has_checked_items:
        print("No checked items found. Nothing to process.")
        return
    
    # Process the body, removing checked items
    new_lines = []
    unchecked_count = 0    
    for line in lines:
        # Keep header lines and unchecked items
        if not re.match(r'- \[x\] v\d+\.\d+\.\d+', line):
            # If it's an unchecked item, count it
            if re.match(r'- \[ \] v\d+\.\d+\.\d+', line):
                unchecked_count += 1
            
            new_lines.append(line)
    
    # Update the count in the second line
    if unchecked_count > 0:
        plural = "s" if unchecked_count > 1 else ""
        new_lines[1] = f"`dirty-waters` has {unchecked_count} new tag{plural} with updates to be attended to:"
    else:
        # No items left, reset to default message
        new_lines = ["# Check Dirty-Waters Updates", "`dirty-waters` has no unattended updates."]
    
    # Update the issue body
    new_body = '\n'.join(new_lines)
    issue.edit(body=new_body)
    print(f"Removed checked items, {unchecked_count} unchecked items remain")
    
if __name__ == "__main__":
    main()