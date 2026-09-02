# Accessibility dumps

Each file here is a recording of what the macOS Accessibility API reported for one window, taken
with `tomwm debug-windows`. Together they are the test corpus for the window classification
heuristic in `Sources/AppBundle/model/AxUiElementWindowType.swift`, exercised by
`AxWindowKindTest`, which recomputes the verdict from the recorded attributes and compares it
against the `TomWM.AxUiElementWindowType` field stored in the file.

That makes them regression tests: if you change the heuristic and a real window would start being
classified differently, a dump here fails.

To add one, run `tomwm debug-windows`, focus the window you care about, and save the output as a
new `.json5` file. Check the recorded verdict is the one you actually want before committing it.

Keys prefixed `TomWM.` are metadata the dump writer adds. Everything else is verbatim from the
Accessibility API and should not be edited: the point of the corpus is that it is real.

The one exception: incidental identifiers inside recorded values (window titles, document paths)
were normalised when this project was forked. None of them feed the classification, which only ever
tests a title for emptiness or the literal string `Window`.
