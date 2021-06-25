# Heading _In_ Title Font?

Here comes the heading:

# Heading

After the heading.

```
func shouldBeSwift() throws {
}
```

```objc
/// Should be objective C
@interface MyObject: NSObject
```

- warning: This is a warning.


* listitem
* callout(lovely): bones!
* listitem

- experiment: What about the giraffes?

### DocC callouts

> important: Do not run

Here comes a tip:

> Tip: Always walk
>
> Another paragraph in the tip.

Warnings have a color.
> Warning: Be alert

Non-callout lines are required between callouts.

> experiment: Nested callouts...
> > experiment: ...work.
> >
> > They work in DocC too though this might not be intentional.

Finally:

> Malformed or untitled callouts appear as *Note*s in DocC but Bebop
> shows them as traditional block-quotes for compatibility with GFM
> and existing docs.

DocC introduces description lists.  Designers everywhere smack their heads.
- term Term1: I first learnt about these on a mainframe
- term Term2: Using *Script* and *Bookmaster*
- term Term3: I still think `:dl.` and `:edl.` before reaching html
- term warning: I'm sure they were called _definition lists_ though.

### Footnotes

Mid-sentence footnote[^1] after[^named] the footnote.

Intervening sentence.

[^1]: Simple _footnote_.

[^named]: More complicated footnote.

    Always the indentation game, where will the backref go?

    One more paragraph.

### Nothing `after` this heading
