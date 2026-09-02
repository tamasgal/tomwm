# Contributing

The main and the most important rule: **read the room!**

* Does your patch look like a typical commit in the repo?
* Does your commit message look like a typical commit message in the repo?
* Does your test look like a typical test in the repo?
* etc.

## Submitting bugs and feature ideas

Open an issue at https://github.com/tamasgal/tomwm/issues

Rules:
* Search for duplicates before opening a new one
* Upvote issues you find useful

**Consider including in bug reports**

* `tomwm debug-windows` output, if the problem is about handling some windows
* Screenshots of problematic windows
* Videos of problematic windows
* What did you try to resolve the issue?
* Your config
* tomwm version
* macOS version

**Consider including in a feature request**

* Use cases!
* Alternative approaches
* Links to docs of similar features in other window managers that you know
* Synopsis, if you suggest a new command
* Mental model description

## Submitting code

Send a GitHub pull request.

Before you do, run `./test.sh`. It builds with warnings as errors, runs the test suite, lints,
regenerates the generated files and checks that the working tree is clean afterwards.

Keep in mind that tomwm is deliberately small. A feature that needs a window tree, per-window
weights or nested splits is a feature for a different window manager. See `dev-docs/architecture.md`
for the shape of the thing, and `docs/guide.adoc` for the model it implements.

**License agreement**. By contributing changes to this repository, you agree to license your
contributions under the MIT license.

Maintainers can apply your patch with arbitrary modifications.

## Share your workflow and tips

Submit your tips as a pull request against `./docs/guide.adoc`
