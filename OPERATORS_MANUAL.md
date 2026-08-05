# kyomei — Operator's Manual

For tutors running live sessions from **`kyomei-admin.html`** (the staff console). Students respond
from **`kyomei.html`**; **`kyomei-display.html`** is the read-only view you project for the room.
`index.html` is a launcher page linking to all three.

---

## Quick reference: keyboard shortcuts

All shortcuts are global to the admin console (not the display), work only while a session is open
(the live session view screen), and are ignored while you're typing into a text field.

| Key | Action | Applies to |
|---|---|---|
| **L** | Show/hide the join QR code and URL on the display | Every session type |
| **G** | Toggle the live feed between chronological and grouped-by-category | Text response sessions only, and only when not guided |
| **Space** | Cycle the results chart type | Quick-tap and Text markup sessions, only once results are revealed |

The join info overlay (**L**) and grouped feed (**G**) are broadcast to the display live — what you
toggle in admin is what the room sees, in real time.

### By session type

A key that "does nothing" for a session type is safe to press — it's a no-op, not an error.

| Session type | L (join info) | G (group feed) | Space (cycle view) |
|---|---|---|---|
| Text response — plain | ✓ | ✓ | — (feed only, nothing to cycle) |
| Text response — guided | ✓ | — | — |
| Quick-tap — configured buttons | ✓ | — | ✓ Buttons → Bar → Pie |
| Quick-tap — Pulse Check (traffic light / confidence) | ✓ | — | — (single dedicated view) |
| Text markup | ✓ | — | ✓ Heatmap → Community highlights |
| Media Vote | ✓ | — | — |
| Running Order | ✓ | — | — |

Text markup's heatmap has two additional view controls (Solo selections / Colorblind palette) —
these are buttons next to the heatmap, not keyboard shortcuts. See §4.

---

## 1. Signing in

Enter your email on the login screen and click **Send login link**. Check your email for a magic
link — there's no password. If your session expires mid-use, the console signs you out
automatically and asks you to sign in again.

---

## 2. The session list

The landing screen after login. Shows every session you've created, newest first, with a badge
showing **"N active"** (text/text-markup/media-vote sessions) or **"N taps"** (quick-tap sessions).
Running Order sessions don't currently update this badge — a busy Running Order session can show
"0 active" on this screen even with teams working. Open the session to see actual team activity.

- **Show archived** — off by default. Switch it on to also see archived sessions, dimmed inline.
- **Archive / Unarchive** — per-session button on the list row. Archiving doesn't delete or reset
  anything; it just gets a finished session out of your way. Toggle it again to bring it back.
- **Delete** — per-session button on the list row; opens the same permanent-delete confirmation
  described in §5.
- Click anywhere else on a row to open that session.

### Pulse Check — one-click launch

Two buttons above the session list skip the whole "New session" form for a quick, disposable
check-in:

- **🔴🟡🟢 Traffic light** — three buttons (Pause / Reflect / Proceed), unlimited retapping.
- **📈 Confidence check** — a 1–10 scale, unlimited retapping.

Both create a new quick-tap session immediately, named with the current time, and drop you
straight into the live session view. They render as a dedicated single-view display (no chart
cycling — there's nothing to cycle to).

---

## 3. Creating a session

**+ New session** → give it a **name** and a **session code** (URL-safe, unique — this is what
students type or scan to join). Pick a **mode**, then fill in the mode-specific fields below.

### Text response
- Add one or more **categories** (students submit free text against a category).
- **Guided reveal** switch — when on, you control which single category is visible to students at
  a time (via the category picker in the live session view), instead of all categories at once.

### Quick-tap buttons
- **Heading / question** — shown above the buttons on both admin and the display.
- **2–10 options**, each with a label and a color from the picker.
- **Limit to one vote per device** — optional soft lock so a device can't tap twice.

### Text markup
- **Passage** — the fixed text students highlight against. **Load test passage** fills in a sample
  for testing.
- **Language** — a locale dropdown (drives word segmentation and automatic left-to-right/
  right-to-left layout). Pick **Other** to enter a BCP-47 tag not in the list.
- One or more **prompts** — each prompt is a separate highlighting task against the same passage.

### Media Vote
- **Video source** — **Local file** (loaded from disk on the display machine) or **mmutube video**
  (paste a video URL or entry ID).
- Students get a fixed vote-button set and can retap freely as the clip plays.

### Running Order
- Add one or more **story items**, each a **headline** and an optional **synopsis**.
- Students don't join individually — a device claims a **team name** and the whole team reorders
  the same item list together from that one device, using up/down buttons (there's no drag-and-drop).
- You can keep editing the item list after teams have joined; the live session view will warn you
  when that's happened, since it means any device with the list already open needs to refresh
  before its next move or submit will work (see §6).

Click **Create session** to go straight into the live session view.

---

## 4. Running a session

The live session view is where you'll spend most of a class. The top bar always has:

- **Open display ↗** — opens `kyomei-display.html` for this session in a new tab, to project.
- **⟳ Refresh** — reloads the current feed/tally/state without leaving the screen.
- **Reset responses** — clears collected data, keeps configuration (see §5).
- **Delete permanently** — irreversible, whole session (see §5).

### Join info (L)

Press **L** to show a QR code and join URL on the display — useful at the start of a session, or
any time you want to remind latecomers how to join. Press **L** again to hide it. A badge in the
session header ("Join info shown (press L to hide)") reflects the current state.

### Guided category / prompt reveal

For **guided text response** and **text markup** sessions, a row of category/prompt buttons sits
above the feed. Click one to make it the active category/prompt — that's what students see and can
respond to. Nothing is shown to students until you pick one.

### Text markup: Compare with…

Once results are revealed, a **Compare with…** dropdown appears (only for text markup). Pick a
second prompt to show its heatmap side-by-side with the active prompt's on the display. Only
applies to the heatmap view, not the community-highlights view.

### Text markup: heatmap view controls

Two button pairs sit above the heatmap once results are revealed (hidden while viewing community
highlights — they only affect heatmap coloring):

- **Consensus / Solo selections** — Consensus is the default hotspot view. **Solo selections**
  switches to highlighting only words picked by 1–2 respondents, fading out everything the room
  broadly agreed on — useful for discussing what one student noticed that the rest missed.
- **Classic / Colorblind** — swaps the blue-to-red heat ramp for a colorblind-friendly
  purple-to-yellow one, for low-contrast projectors or colorblind viewers in the room.

Both broadcast to the display live, same as **Compare with…**, and both reset to Consensus/Classic
whenever you freshly reveal results.

### Media Vote transport controls

- **Play / Pause** — drives playback on the display remotely. The button is green when it will
  start playback, yellow when it will pause.
- **Restart** — seeks back to 0:00.
- **Seek to (mm:ss)** — type a time (e.g. `1:30`) and click **Seek**, or press **Enter** in the
  field.
- A status line above the controls shows whether the display has actually loaded the video
  (**"Display: ready"** vs **"Display: waiting for video to load"**) — the display requires one
  local click to start local-file or mmutube playback before it responds to remote commands.
- **Votes collected** — a live running count.
- **Timeline bucket size** (1/5/10/15/30s) — controls the granularity of the reveal-gated timeline
  reconstruction of how votes evolved across the clip.

### Running Order: teams, activity, and views

Running Order is self-contained — it doesn't use the live feed, chart cycling, or the shared
reveal button described below; it has its own panel with its own **Reveal results** button.

- **Team activity** — a running summary: "N active · N submitted · N total seen." Active means a
  team hasn't submitted and has moved an item in the last 5 minutes.
- **Reveal results** — gates the display the same way it does for other session types: nothing
  about team progress is shown to the room until you click it.
- Once revealed, two controls decide what the display shows:
  - **View a team's final order** — a dropdown of teams that have submitted; picking one shows
    that team's final running order on the display.
  - **Aggregate view** — shows the combined picture instead: average final position per item,
    moves per item, and pairwise reversals across all submitted teams.
- Before you pick either one, the display shows nothing about team progress — there's no default.

### The live feed

New submissions stream in as they arrive (newest first). Each text-response entry has:

- **Park** — sets the entry aside, removing it from the feed.
- **Delete** — click once to arm ("Confirm delete?"), click again within 3 seconds to remove it.
  Arming resets automatically if you don't confirm in time.

Both actions are immediate and there's no UI to bring an entry back — if you need it, use
**Reset responses** to start over instead of trying to recover a single entry.

**G** groups the feed by category instead of showing it chronologically — plain text-response
sessions only (not guided, not quick-tap/text-markup/media-vote). The display mirrors whichever
view you're in.

### Reveal results

For quick-tap, text markup, Media Vote, and Running Order sessions, a **Reveal results** button
gates the aggregate view (chart / heatmap / timeline / team rankings) — students and the display
see "Collecting…" until you click it. Click again to hide results without losing any collected
data. Plain text-response sessions have no reveal gate; the feed is always visible. Running Order's
reveal button lives in its own panel (see above) rather than the shared button described here, but
behaves identically.

### Cycling chart types (Space)

Once results are revealed, **Space** cycles the aggregate view:

- **Quick-tap**: Buttons → Bar → Pie (repeats). Pulse Check sessions (traffic light / confidence)
  have only one view each, so Space does nothing for them.
- **Text markup**: Heatmap → Community highlights (repeats). Revealing results always lands on
  Heatmap first.

---

## 5. Ending or clearing a session

- **Reset responses** — click once to arm ("Confirm reset?"), click again within 3 seconds to
  execute. Deletes all collected responses and transport-event history, hides results again, and
  clears any active guided category / active prompt / media transport state. For Running Order,
  this also clears team claims, moves, and submissions — teams need to rejoin with a team name
  afterward. **Configuration (categories, options, passage, prompts, story items) is untouched** —
  the session is ready to run again from scratch.
- **Archive / Unarchive** — from the session list (§2); doesn't touch data.
- **Delete permanently** — top bar or session-list button. Opens a confirmation showing exactly how
  many responses and configuration items will be lost. You must type the session's exact **session
  code** to enable the delete button. This cannot be undone.

---

## 6. Troubleshooting

- **"Reconnecting to live feed…" banner** — a transient Realtime disconnect; it clears itself once
  the connection recovers. Data isn't lost, just not streaming live in the meantime.
- **"Display: waiting for video to load" won't clear (Media Vote)** — the display needs one local
  click on its own "Load video" prompt before it can respond to remote Play/Pause/Seek. Check the
  projector/display screen directly.
- **Your login session expires mid-session** — the console signs you out automatically and shows an
  error; sign back in with a fresh magic link and reopen the session.
- **A student says their Running Order team is gone / can't rejoin (Running Order)** — a team name
  is released after 5 minutes of inactivity from its device, and any device can then claim it. If
  the original device comes back, it sees "Another device took over this team name" and has to
  rejoin as a (new) team. This is by design, not a bug — it stops one distracted device from
  permanently locking out a team name.
- **"Teams have already joined" warning when editing story items (Running Order)** — safe to
  proceed; any device with the item list already open just needs to refresh before its next move or
  submit will go through cleanly.

---

*kyomei — Facilitation software by Andy Dickinson · a.dickinson@mmu.ac.uk*
