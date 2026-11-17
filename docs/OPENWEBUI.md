# Working from Open WebUI (chat mode)

Open WebUI is a chat window. It cannot create files, run commands or look at your screen, so
two small scripts do those parts for it:

- `scripts/bundle.py` packs a task, the rules and your current code into **one file**.
- `scripts/apply_reply.py` takes the model's answer and **saves its files** into the right folders.
  It refuses anything outside `app/` and `firmware/`, so the model cannot touch the protocol, the
  tests or the simulator, and it backs up any file it replaces.

You still run `python scripts/check.py` yourself. That is the part that tells you if it worked.

## One-time

Use the model `devstral-vector` (made in `docs/SETUP.md`). It has a 32768-token memory setting built in.
If its answers ignore the instructions or get cut off, open the chat's settings in Open WebUI
(Advanced Params), and set Context Length to 32768.

## For each task (example: task 5)

1. **Make the bundle.** In a terminal in the kit folder:

   ```
   python scripts/bundle.py 5
   ```

   It writes `bundles/task_05.md` and tells you its size. It is usually 5,000 to 15,000 tokens.

2. **Start a new chat** in Open WebUI with `devstral-vector`. A new chat per task keeps the model on track.

3. **Give it the bundle.** The most reliable way is to open `bundles/task_05.md` in any text editor, select all
   (Ctrl+A), copy (Ctrl+C), paste into the chat box, and add the line: `Do the task in this bundle.`
   Attaching the file also works, but Open WebUI may search inside attachments instead of reading all of
   them. If it offers an option like "use entire document", choose it.

4. **Save its answer.** Click the copy button under the model's reply. In your terminal run:

   ```
   python scripts/apply_reply.py
   ```

   Paste with Ctrl+Shift+V, then press Ctrl+D on an empty line. (Or save the reply as `reply.txt` and run
   `python scripts/apply_reply.py reply.txt`. Add `--dry-run` to preview without saving.)

   The script lists what it wrote and what it refused. It also prints any commands the model suggested.
   **It never runs them.** Read them, and run the ones that make sense.

5. **Check.** `python scripts/check.py`.
   - PASS or SKIP: tick it off, move to the next task.
   - FAIL: run `python scripts/bundle.py 5` again. The new bundle now includes `last_check.txt` and your current
     code, so just paste it into a new chat and say: `The check failed. Fix it.`

## Good to know

- **Task 01 needs commands first.** Its reply will include a `flutter create` command. Run the commands, then
  apply the files.
- **If the model gives fragments** ("rest of the file unchanged"), the script will save the fragment and
  break the file. Reply: `Resend as COMPLETE files in the FILE: format.` The backups in `.backups/` let you undo.
- **Big projects:** the bundle stops at about 60,000 characters and lists what it left out. If the model needs
  one of those files, paste it in.
- **Refused files are a signal, not a bug.** If the model keeps trying to change `protocol/`, `tools/`, `sim/` or
  `tests/`, stop and paste the refusal to Claude.
- Stuck after 3 rounds? Paste `last_check.txt` and `PROGRESS.md` to Claude, as in the main workflow.
