/* DevPath accounts. Fill in the two values from Supabase:
   Project Settings → API (or "API Keys").
   url: your Project URL, like https://abcdefghijkl.supabase.co
   key: the "publishable" key (starts with sb_publishable_) or the older "anon public" key.
   Both are safe to put on a public website: the database only allows
   signing in, saving your own progress, and listing learners.
   Leave them empty to run DevPath without accounts. */
window.DEVPATH_CLOUD = {
  url: "",
  key: ""
};
