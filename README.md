# My Chain Link

Social network — no filters, camera-only uploads, authentic connections.

## Deploy

- **Netlify**: Drag `index.html` into [Netlify Drop](https://app.netlify.com/drop), add custom domain `mychainlink.ca`
- **GitHub Pages**: Push to repo, enable Pages, add `CNAME` file with `mychainlink.ca`
- **Vercel**: `vercel --prod`
- **Any host**: Upload `index.html` — zero build step

## Supabase Setup

Replace `SURL` and `SKEY` in `index.html` with your project credentials.
Enable Email + OAuth providers in Supabase Auth settings.

## Local Preview

```bash
cd mychainlink
python3 -m http.server 8080
```

Open http://localhost:8080