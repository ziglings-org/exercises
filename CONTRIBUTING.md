# Contributing

By reading this document, you have already entered the Elite Hall
of Ziglings Maintenance!


## The Ziglings Audience

Ziglings is intended for programmers of all experience levels. No
specific language knowledge is expected. Anyone who can install
the current Zig snapshot, setup a copy of Ziglings, and knows
common language building blocks (if/then/else, loops, and
functions) is ready for Ziglings.

Zigling's excercises are self-contained. If you can't solve
an exercise from the information you've gleaned so far from
Ziglings, then the exercise probably needs some additional work.
Please file an issue!

If an example doesn't match a description or if something is
unclear, please file an issue!


## Spelling/Grammar

If you see any typos, please file an issue...or make a pull
request!

No mistake is too small. The Ziglings must be perfect. :-)


## Ideas

If you have ideas for new lessons or a way Ziglings could be
improved, don't hesitate to file an issue.

Feel free to submit new exercises but please understand that they
may be heavily edited or rejected entirely if we feel they don't
fit for one reason or another.

## Platforms and Zig Versions


Because it uses the Zig build system, Ziglings should work
wherever Zig does.

Since Ziglings is a Zig language learning resource, it tracks the
current development snapshots of Zig from the official website
downloads page.

If you run into an error in Ziglings caused by breaking changes
in the latest development build of Zig, that's a new bug in
Ziglings. Please file an issue...or make a pull request!

For the latter, also read "The Secrets” section.


## Formatting

All exercises should conform to `zig fmt`.


## Pull Request Workflow

Ziglings uses the "standard" Codeberg workflow as guided by the Web
interface.  Specifically:

* Fork this repository
* Create a branch from `main` for your work:
      `git checkout -b my-branch`
* Make changes, commit them
* When your changes are ready for review, push your branch:
      `git push origin my-branch`
* Create a pull request from your branch to `ziglings/main`
* Your faithful Ziglings maintainers will take a look at your
  request ASAP (we don't talk about May-July, LOL)
* Once the changes are reviewed, your request will be merged and
  eternal Ziglings contributor glory is yours!


## Licence

If you submit your contribution to the repository/project,
you agree that your contribution will be licensed under
the license of this repository/this project.
Please note, it does not change your rights to use your own
contribution for any other purpose.


## The Secrets

If you want to peek at the secrets, take a look at the `patches/`
directory.

Every Ziglings exercise contains mistakes on purpose.
To keep our automated tests happy, each exercise also
has a patch in `patches/healed` that “heals” it.

When you change an exercise, you will usually need to update
its patch too. That’s where our little helper Gollum comes in:

  1. In the project root, create a folder called `answers/`
  2. Put your solved version of the exercise file in there
  3. Back in the root, run:
     `./patches/gollum <exercise-number>`<br>
     For example: `./patches/gollum 106`
     This will generate a shiny new patch.

Double-check everything by asking the magical Eowyn:
`./patches/eowyn`<br>
If all tests pass: You are done!

Don’t forget to commit the patch file.
