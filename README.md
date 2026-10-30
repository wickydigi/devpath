# DevPath

A self-directed, bachelor-level learning platform: **Software Engineering → Network Engineering → Cybersecurity → Machine Learning & AI**, with daily review, hands-on labs, mock exams, and the Office capstone.

The site is one main file, `index.html`, plus a small `config.js` for optional accounts. There's no build step and no server code, so hosting is simple and free.

Files:
- `index.html`: the whole app
- `config.js`: your account settings (leave it empty to skip accounts)
- `supabase-setup.sql`: run once in Supabase to create the accounts database
- `README.md`: this guide

---

## Option A: GitHub Pages (recommended, free)

This also counts as your first real Git practice.

1. Sign in at **github.com** (create an account if you don't have one).
2. Click **+** (top right) → **New repository**.
   - Name: `devpath`
   - Visibility: **Public** (free GitHub Pages needs a public repository)
   - Click **Create repository**.
3. On the new repository page, click **uploading an existing file**.
   Drag in `index.html`, `config.js`, `supabase-setup.sql`, and `README.md`, then click **Commit changes**.
4. Go to **Settings** → **Pages** (left sidebar).
   - Under **Build and deployment**, set **Source** to **Deploy from a branch**.
   - Set **Branch** to `main` and the folder to `/ (root)`, then click **Save**.
5. Wait one or two minutes, then refresh the Pages settings. Your site's address appears at the top:
   `https://YOUR-USERNAME.github.io/devpath/`

**Doing it from the terminal instead (more practice):**

```bash
git init
git add index.html config.js supabase-setup.sql README.md
git commit -m "Add DevPath"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/devpath.git
git push -u origin main
```

Then do step 4 above.

---

## Option B: Vercel (also free)

1. Do steps 1–3 of Option A, so the files are in a GitHub repository.
2. Go to **vercel.com** and sign up with your GitHub account.
3. Click **Add New…** → **Project**, find your `devpath` repository, and click **Import**.
4. Leave **Framework Preset** as **Other**, and leave the build settings empty. Click **Deploy**.
5. Your site will be at an address like `https://devpath-xxxx.vercel.app`.

Every time you push a change to GitHub, Vercel redeploys automatically. That's CI/CD, from lesson 15 of Software Engineering.

---

## Accounts for you and your friends (up to 5 people)

With accounts, everyone signs in with a **username and PIN**. Each person's progress is saved online, so it follows them to any device: phone, laptop, or tablet. Nobody sees anyone else's progress, but everyone can see who's learning, their XP, lessons done, and when they were last active.

It uses **Supabase**, a free online database. You only set it up once, in about 10 minutes.

### 1. Create the database

1. Go to **supabase.com** and sign up (signing in with GitHub is easiest).
2. Click **New project**. Give it a name like `devpath`, create a database password (save it somewhere; you won't need it for DevPath), pick a region close to you, and click **Create new project**. Wait about a minute.
3. In the left sidebar, open **SQL Editor**. Click **New query**.
4. Open `supabase-setup.sql`, copy everything, paste it in, and click **Run**. You should see "Success. No rows returned."

### 2. Connect DevPath to it

1. In Supabase, open **Project Settings** (the gear icon) → **API Keys** (on some projects it's called **API**).
2. Copy the **Project URL** (it looks like `https://abcdefghijkl.supabase.co`). You'll find it under **Project Settings → Data API**, or on the project's home page.
3. Copy the **publishable** key (it starts with `sb_publishable_`). If you only see older keys, use the one called **anon public**.
4. On GitHub, open `config.js` → click the pencil icon to edit. Paste both values between the quotes:

   ```js
   window.DEVPATH_CLOUD = {
     url: "https://abcdefghijkl.supabase.co",
     key: "sb_publishable_xxxxxxxxxxxx"
   };
   ```

5. Click **Commit changes**. After a minute, your site shows a **Who's learning?** screen.

These two values are safe on a public website. The database is locked: the site can only sign in, save that person's own progress, and list learners.

**Never** put the `service_role` or `secret` key in `config.js`.

### 3. Sign in

- **First time:** type a new username (3 to 20 lowercase letters, numbers, or `_`) and choose a PIN of 4 to 8 digits. The account is created on the spot. If that browser already had progress, it moves into the new account.
- **Other devices:** sign in with the same username and PIN, and your progress appears.
- **Friends:** send them your site's link. Each one creates their own username.
- **Switching people on one device:** **My plan** → **Switch learner**.
- **Who's learning:** **My plan** → **Account and learners** shows everyone. You can also see the full table in Supabase → **Table Editor** → `learners`.

### Good to know

- **5 accounts maximum.** To allow more, change `select 5` in `supabase-setup.sql` to a bigger number and run it again.
- **Forgotten PIN or removing someone:** in Supabase → **Table Editor** → `learners`, delete that person's row. They can then sign up again, but their old progress is gone.
- **PINs are stored scrambled**, not as plain text, and wrong guesses are slowed down. A PIN isn't a strong password, though: it keeps friends' progress apart; it isn't for anything secret. Use 6 digits rather than 4.
- **Free plan pause:** Supabase pauses free projects after about a week with no activity. If sign-in stops working after a break, open your Supabase project and click **Restore** (or **Resume**).
- **Offline:** progress keeps saving in the browser and syncs when you're back online.

---

## Moving your progress

Without accounts, progress is saved in your browser, separately for each website address. So your progress in the Claude version won't automatically appear on your new site. (With accounts, it's simpler: sign in on your site and progress you made in that browser moves into your new account the first time.)

1. In the Claude version: **My plan** → **Copy backup code**.
2. On your hosted site: **My plan** → paste the code under **Restore from a backup code** → **Restore**, then tap again to confirm.

Do the same whenever you switch between your laptop and your phone.

---

## Updating

When Claude sends you a new `index.html`, replace the old file in your GitHub repository: open the file on GitHub → click the **…** menu → **Delete file**, then upload the new one. Don't replace `config.js`, or you'll need to paste your settings in again. Your progress is safe, because it's stored in your account or your browser, not in the file.

---

## What needs the internet

The page loads its fonts from Google Fonts and the SQL Lab engine from jsDelivr. Accounts talk to your Supabase project. Everything else, including all lessons, logos, icons, and the machine learning labs (which train real models in your browser), is inside `index.html`.
