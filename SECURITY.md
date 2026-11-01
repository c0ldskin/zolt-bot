# Security

Zolt can run commands on your Mac (always after you click **Allow**) and can read files in your home folder to answer questions. So we take security seriously.

## Reporting a problem

Please **don't** open a public issue. Use GitHub's private reporting instead:
**[Report a vulnerability](https://github.com/c0ldskin/zolt-bot/security/advisories/new)**

Include what you did, what happened, and how to reproduce it. You'll get a reply within a week.

## What counts

Anything that gets around Zolt's safety design, for example:

- An action running without the Allow/Deny dialog, or the dialog hiding part of what will run
- Zolt reading a blocked secret location (`.ssh`, `.aws`, Keychains, `.env` files and the rest of the list in `Sources/main.swift`)
- Text from a web page, file, screenshot or meeting making Zolt act or leak data
- Meeting notes starting without your OK
- Spoken words ending up in `~/.zolt/zolt.log`

## Supported versions

Only the latest release gets fixes.
