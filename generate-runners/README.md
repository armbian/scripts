# This snippet will install as many Github runners you want

    PAT = personal access token (generate at your account, settings -> developers settings -> PAT)
    START = define start number, 0001, 0002, ... 01,02
    STOP  = define stop number
    NAME = name / keyword of this runner group

Token needs:

- admin:org Full control of orgs and teams, read and write org projects
- write:org Read and write org and team membership, read and write org projects
- read:org Read org and team membership, read org projects
- manage_runners:org Manage org runners and runner groups
