# Setup

> The build moved to Claude Code. Steps 3 and 4 (Ollama, Devstral, Cline) are optional now; you only need
> Python (step 1), Flutter (step 2) and, for firmware tests, PlatformIO (step 5).

Do these once. Use the computer you will build on (a Mac, Windows PC or Linux machine).
If a step fails, copy the exact error text to Claude.

## 1. Python (checks and simulator)

You need Python 3.10 or newer. Check with `python --version` (on Mac/Linux it may be `python3`).
Then, in the kit folder:

```
pip install -r requirements.txt
python scripts/check.py
```

A good result says `[PASS] Protocol, simulator and test data (Python)`.

## 2. Flutter (builds the app)

Install Flutter from https://docs.flutter.dev/get-started/install and follow its page for your
computer. Then run:

```
flutter doctor
```

`flutter doctor` lists what is missing. You only need the parts for the platforms you want first.
Start with your own computer's desktop app (macOS, Windows or Linux). Phones come later.

- iPhone and iPad builds need a Mac with Xcode, and an Apple developer account to put them on other people's devices.
- Android builds need Android Studio.

## 3. The coding model (Ollama and Devstral Small 2)

1. Install Ollama from https://ollama.com. Devstral Small 2 needs Ollama 0.13.3 or newer.
2. Download the model (about 15 GB):

   ```
   ollama pull devstral-small-2
   ```

3. Make a Vector-tuned copy with a safe memory setting and low randomness:

   ```
   ollama create devstral-vector -f docs/Modelfile
   ```

   Use `devstral-vector` as the model name in your coding tool from now on.

The model advertises a very large context window, but a big window uses a lot of memory.
`docs/Modelfile` sets 32768 tokens, which is plenty for one task file and a few source files.
If your computer runs out of memory or crawls, lower `num_ctx` in the Modelfile to 16384
and re-run the `ollama create` line.

## 4. A tool that lets the model edit files

A model alone can only chat. You need a coding tool that lets it read files, edit them and run
commands. Two options that work with Devstral:

- **Mistral Vibe CLI**: Mistral's own open-source command-line coding assistant, built for Devstral.
  Install and configure it from its README: https://github.com/mistralai/mistral-vibe
  Point it at your local Ollama model `devstral-vector`.
- **Cline** (a VS Code extension): choose Ollama as the provider and `devstral-vector` as the model.

Either way: open the **kit folder** as the project, so the tool can see `AGENTS.md`.
If the tool does not read `AGENTS.md` by itself, tell it as your first message:
"Read AGENTS.md first and follow it for everything."

(I could not test your exact tool or its menus, so follow its own README for the connect-to-Ollama step.)

## 5. PlatformIO (only for firmware, later)

Needed in task 10. Install the PlatformIO extension in VS Code, or run `pip install platformio`.
`python scripts/check.py` skips the firmware check until `pio` is available.

## Check that it all works

```
python scripts/check.py      # Python part passes
flutter doctor               # shows the platforms you can build
ollama run devstral-vector   # type "hello", then /bye
```
