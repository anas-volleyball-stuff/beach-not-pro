# GitHub Pages Deployment

This project deploys through GitHub Actions using `.github/workflows/deploy.yml`.

## Repository Settings

In GitHub, open the repository settings for:

`anas-volleyball-stuff/beach-not-pro-tour`

Then set:

- Settings > Pages > Source: `GitHub Actions`
- Settings > Secrets and variables > Actions > Variables:
  - `VITE_SUPABASE_URL`
- Settings > Secrets and variables > Actions > Secrets:
  - `VITE_SUPABASE_ANON_KEY`

Use the base Supabase project URL, not the REST endpoint:

```bash
https://eqlcynajawklthwxlonv.supabase.co
```

## Deploy

Push to `main`, or open Actions and run `Deploy to GitHub Pages` manually.

The live URL will be:

```bash
https://anas-volleyball-stuff.github.io/beach-not-pro-tour/
```
