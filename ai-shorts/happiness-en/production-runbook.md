# Production Runbook

Everything below is ready to execute. It has **not** been run: the Higgsfield
workspace is on the `free` plan with **0 credits**, and every `generate_*` step
is paid.

## Budget shape

Read the shot list before picking models. **Ten of the fourteen shots barely
move** — "camera perfectly still", "static", "nothing but breath", "otherwise a
photograph". Only four have real camera work: the slow push in scene 12, the
drift back in scene 10, and the two walking/static-follow frames.

So don't spend video credits fourteen times. Spend them four times:

| Shots | Treatment |
|---|---|
| 12, 10, and the two you judge need it | Image-to-video on a good model |
| the rest | Strong stills + a slow Ken Burns move in the editor — free |

Stills are cheap to reroll, clips are not, and pushing a near-static frame
through a video model is how faces go soft. Generating the still and moving it
in the edit looks *better* here, not just cheaper.

## Pipeline

### Step 1 — Generate 14 stills

One `generate_image` per scene, using the scene's **Image** prompt plus the
global style suffix from `script-en.md`. Aspect ratio 9:16.

No character locking is needed — the source uses unrelated people per scene
(see `source-analysis.md`). The one exception is the suit man in scenes 7 and
10: same dark suit, same build, shot from behind both times. No face to match,
so matching the wardrobe in the prompt is enough.

Review all fourteen as a contact sheet before spending any video credits.

### Step 2 — Animate the four that move

`generate_video`, image-to-video, seeded with the still and driven by the
scene's **Motion** note. Most models quantise to 5s — generate 5s and trim.

**Turn native audio off.** Seedance 2.0, Kling v3.0, Veo 3 and Gemini Omni all
default to generating audio (`generate_audio: true` / `sound: "on"`). Ambient
noise on every clip will fight the narration. Silent clips are also cheaper.

### Step 3 — Narration

This is where the video is won or lost. `list_voices`, pick a low, dry male
voice — if nothing has the right texture, a dedicated TTS is worth going
outside for. One voice, one continuous take of the whole script (see
`script-en.md` § *The narration is one continuous read*), not fourteen
fragments.

### Step 4 — Assemble

Cut the picture against the finished VO — cut points in the script, not the
other way round. Ken Burns the ten static stills. Lay in the music bed at
−22 LUFS. Burn in `subtitles.srt`, then nudge each card onto the actual
narration. Build the scene 14 title card in English over the blank cover.
Optionally `upscale_video` the finished cut.

`ffmpeg` is **not** installed in this container — assembly needs it installed,
or gets done in an editor.

## Model notes

Higgsfield is a router, not a model. Through it: Veo 3, Kling v3.0,
Seedance 2.0, Gemini Omni, Grok Video 1.5 for video; Nano Banana Pro,
Soul 2.0, Cinema Studio for stills.

Several of those are flagged `supports_unlim` — unlimited generations on some
plans. For a project whose cost is dominated by rerolls, **check whether a paid
plan unlocks `unlim` on Nano Banana Pro or Soul 2.0 before buying credits.**
That matters more than which model you pick.

Call `models_explore` for current pricing and `balance` before starting — don't
take a number from this file.

## What is unverified

The source could not be viewed from this session (YouTube blocked by egress
policy, `403`, checked twice). The shot list comes from two independent
server-side analysis passes which **disagree on casting, timing and shot
framing** — see `source-analysis.md` § *Where the passes disagree*. The beat
map and the warm/cool palette alternation are corroborated by both passes and
can be trusted. Individual wardrobe and framing details cannot. Spot-check the
original before committing credits.
