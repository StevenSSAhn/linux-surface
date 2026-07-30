# Production Runbook

Everything below is ready to execute. It has **not** been run: the Higgsfield
account is on the `free` plan with **0 credits**, and every `generate_*` step
is paid. Add credits, then work down this list.

## Pipeline

Stills first, then image-to-video. Generating each scene directly as
text-to-video gives you fourteen strangers; locking a portrait per character
first and passing it as a reference is what makes the recurring faces hold.

### Step 1 — Lock the four characters

One `generate_image` call per character in `script-en.md` § *Character bible*
(NARRATOR-MAN, SHOP-WOMAN, SUIT-MAN, PRAYER-MAN). Neutral portrait, same
lighting for all four. Keep the returned media ids.

### Step 2 — Generate 14 stills

One `generate_image` per scene, using the scene's **Image** prompt plus the
global style suffix. For the ten scenes with a locked character, pass that
character's portrait as the reference image. Aspect ratio 9:16.

Review all fourteen as a contact sheet before spending any video credits —
a bad still is cheap to redo, a bad clip is not.

### Step 3 — Animate each still

One `generate_video` per scene, image-to-video, seeded with the still from
step 2 and driven by the scene's **Motion** note. Request the scene's duration
from the shot list (most models quantize to 5s — generate 5s and trim in the
edit; scene 4 is generated at minimum length and cut hard to 2s).

### Step 4 — Narration

`list_voices` → pick a low, dry male voice in the 50s range, or `create_voice`
if nothing fits. Then `generate_audio` on the full VO text from `script-en.md`,
recorded as one continuous take rather than fourteen fragments — a single take
keeps the cadence consistent and gives the edit room to breathe against the
cuts.

### Step 5 — Assemble

Cut the clips to the shot-list timings against the narration track, lay in the
music bed at −22 LUFS, burn in `subtitles.srt` with the caption style from
`script-en.md`. Optionally `upscale_video` the finished cut.

Note: `ffmpeg` is **not** installed in this session's container — assembly
either needs it installed, or gets done in an editor.

## Cost

Cost scales with model choice and clip count: ~18 image generations
(4 portraits + 14 stills, before retries), 14 video generations, 1 audio
generation. Call `models_explore` for per-model pricing and `balance` to check
the account before starting — don't take a number from this file, the routing
changes.

## What I could not verify

The source video could not be viewed directly from this session — YouTube is
blocked by the environment's egress policy (`www.youtube.com:443` → 403). The
shot list in `source-analysis.md` comes entirely from Higgsfield's server-side
analysis of the URL, which fetched it on its own network. It is a good
breakdown but it is a machine reading: the palette notes, casting details and
timings should be spot-checked against the original before you commit credits.
