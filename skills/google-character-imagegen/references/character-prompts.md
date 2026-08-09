# Character Prompt Templates

Use these when a user asks for generated character art but only gives a rough idea.

## Portrait

```text
Create a single polished character portrait of <subject>.
Focus on face readability, hairstyle, costume silhouette, and one signature prop.
Style: <style>.
Mood: <mood>.
Details: <details>.
Background: clean studio backdrop.
```

## Full Body

```text
Create a full-body character concept of <subject>.
Show the whole outfit, shoes, proportions, and major accessories clearly.
Style: <style>.
Mood: <mood>.
Details: <details>.
Background: neutral concept-art background.
```

## Turnaround Sheet

```text
Create a turnaround sheet of <subject>.
Show front, three-quarter, side, and back views in one consistent composition.
Keep costume details and silhouette consistent across all views.
Style: <style>.
Details: <details>.
Background: clean white production sheet.
```

## Expression Sheet

```text
Create an expression sheet of <subject>.
Show at least six expressions: neutral, happy, angry, worried, surprised, determined.
Maintain the same costume, hairstyle, and face proportions across all expressions.
Style: <style>.
Details: <details>.
Background: clean production sheet.
```

## Sprite Concept

```text
Create a sprite-ready concept of <subject>.
Prioritize clean shapes, strong silhouette, readable color breakup, and simplified accessories.
Style: pixel-art friendly 2D concept art.
Details: <details>.
Background: plain backdrop.
```

## Prompting Notes

- Keep the subject line concrete: role, age band, silhouette, outfit function, and one signature prop.
- For game production, specify if the image is for portrait UI, dialogue art, full-body reference, or turnaround.
- If using `imagen`, prefer English prompts.
- If the user wants consistency across multiple generations, reuse the same base prompt and change only one narrow attribute each run.
