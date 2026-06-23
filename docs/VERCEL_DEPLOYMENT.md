# Vercel Deployment

## 1. Import the Project

Push this repository to GitHub, GitLab, or Bitbucket, then import it in Vercel.

## 2. Configure Build Settings

Vercel should detect Vite automatically.

- Framework Preset: Vite
- Build Command: `npm run build`
- Output Directory: `dist`
- Install Command: `npm install`

## 3. Add Environment Variables

Add these variables in Vercel Project Settings > Environment Variables:

```bash
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

Add them for Production and Preview.

## 4. Deploy

Trigger a deployment. After deployment, open the app in two browsers and save a score in one. The other browser should update automatically through Supabase Realtime.

## 5. Production Checklist

- Supabase migration has been run.
- Realtime is enabled for the seeded tables.
- Vercel environment variables are set.
- `npm run build` passes locally or in CI.
- Scorekeeper access policy is acceptable for the tournament.
