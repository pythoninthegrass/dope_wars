---
created: 2026-09-25T14:58:27 (UTC -05:00)
tags: []
source: https://dopewars.sourceforge.io/faq.html
author: 
---

# Frequently-Asked Questions

> ## Excerpt
>
> Main Index *
  News*
  Documentation *
  FAQ*
  Download *
  Screenshots*
  Active servers *
  SourceForge project page*
  GitHub

---
[Main Index](https://dopewars.sourceforge.io/) \* [News](https://dopewars.sourceforge.io/news.html) \* [Documentation](https://dopewars.sourceforge.io/docs/) \* FAQ \* [Download](https://dopewars.sourceforge.io/download.html) \* [Screenshots](https://dopewars.sourceforge.io/screenshots/) \* [Active servers](https://dopewars.sourceforge.io/metaserver.php?getlist=2) \* [SourceForge project page](https://sourceforge.net/projects/dopewars/) \* [GitHub](https://github.com/benmwebb/dopewars)

- [What operating systems is dopewars available for?](https://dopewars.sourceforge.io/faq.html#os)
- [What other packages do I need to install dopewars?](https://dopewars.sourceforge.io/faq.html#depend)
- [I want to help out. What can I do?](https://dopewars.sourceforge.io/faq.html#help)
- [I can't download the Windows version!](https://dopewars.sourceforge.io/faq.html#windows)
- [Is dopewars available for my platform and operating system?](https://dopewars.sourceforge.io/faq.html#platform)
- [I thought this game was called "Dope Wars 2.0" or "Dopewars 2000" or "Drug Wars" - what's going on?](https://dopewars.sourceforge.io/faq.html#others)
- [All of a sudden the game just stops for no reason, and I have to restart. What's going on?](https://dopewars.sourceforge.io/faq.html#days)
- [31 turns isn't long enough. How do I get a longer game?](https://dopewars.sourceforge.io/faq.html#moredays)
- [The game could do with some sounds or extra graphics - can you add them?](https://dopewars.sourceforge.io/faq.html#sounds)
- [The game segfaults all the time when I try to page or talk to other players! I'm using the latest RPM.](https://dopewars.sourceforge.io/faq.html#segfault)
- [Do I _really_ need GLib to build dopewars from the source code? I just want to use the text-mode client.](https://dopewars.sourceforge.io/faq.html#glib)
- [I've found a bug! Fix it please.](https://dopewars.sourceforge.io/faq.html#bug)
- [Can you add _&lt;feature&gt;_ ?.](https://dopewars.sourceforge.io/faq.html#feature)

**What operating systems is dopewars available for?**

dopewars was originally developed on a RedHat Linux box, and should be portable to most flavours of Unix. It will also run under Win32 systems (Windows 7 or later). See also [this other FAQ.](https://dopewars.sourceforge.io/faq.html#platform)

**What other packages do I need to install dopewars?**

You'll need the [GLib](http://www.gtk.org/) library for starters. (See [this other FAQ](https://dopewars.sourceforge.io/faq.html#glib).) To use the text-mode client on Unix machines, the **curses** library is required (although the similar **ncurses** and **cur\_colr** libraries should work just fine). To use the graphical [GTK+](http://www.gtk.org/) client on Unix machines, the GTK+ libraries are required. To use multi-player dopewars, you'll need the [curl](https://curl.se/download.html) library. No libraries other than GLib and curl are required on Win32 platforms.

**I want to help out. What can I do?**

Even if you're not a programmer, there are lots of things that you can do, such as designing sounds or graphics for the program, translating it into non-English languages, or customising the game with local city and drug names. See the [How to contribute](https://dopewars.sourceforge.io/docs/contribute.html) page.

**I can't download the Windows version!**

Just click on the link on the [download page](https://dopewars.sourceforge.io/download.html). Opt to "Run this program from its current location" and click OK. Internet Explorer will probably, at this point, pop up a security warning. There is nothing wrong with the program - this just means that I haven't forked out buckets of cash to buy an Authenticode signature to placate Internet Explorer. Click the "Yes" button, and then a fairly standard installation program will run. Once this program has finished, you should be able to run dopewars from your Start Menu or, if you clicked the relevant option, directly from your Desktop.

**Is dopewars available for my platform and operating system?**

As [stated above](https://dopewars.sourceforge.io/faq.html#os), dopewars works on Microsoft Windows systems and most Unix variants, which includes Linux and Mac OS X. Binaries are provided for a number of popular operating systems on the [download page](https://dopewars.sourceforge.io/download.html) (some of these binaries are available directly from this site, while some are built by third parties). For other operating systems (e.g. most palmtop computers), dopewars probably won't work, but don't despair - there are many games that are very similar to dopewars, and so it's likely that you can play one of these on your system. See the [next FAQ](https://dopewars.sourceforge.io/faq.html#others) for a list.

**I thought this game was called "Dope Wars 2.0" or "Dopewars 2000" or "Drug Wars" - what's going on?**

dopewars is based loosely on "Drug Wars", a game written by John E. Dell back in the 1980's. It draws more closely on the MS-DOS rewrite, titled "Dopewars". (In fact, the "antique" mode of dopewars follows the MS-DOS program particularly closely.) There are many other programs based on "Drug Wars" available on the net; some of these are listed below. Please note that these programs are not all free software, and are not compatible with "dopewars" from this site (for example, you cannot connect to a dopewars server with Beermat's Windows program - if you want a Windows or Mac OS X version of "this" dopewars, check out the download page.)

- [Dope Wars for Windows](http://www.beermatsoftware.com/dopewars/) (Beermat Software). By far the most popular dopewars-like game. Only available for Windows, only supports single-player games, and is not free; however, a free trial version is available, and high scores can be posted on Beermat's website.
- [Dopewars 2000](http://www.dopewars2000.co.uk/). Also Windows-only. Freeware.
- [WinDealer](http://www.umr.edu/~schuette/windealer.html). An incomplete Windows version.
- [Chronic 2005](http://www.chronic2005.com/). Another Windows version, with graphics.
- [DrugWarz](http://www.geocities.com/drugwarz/drugwarz.htm). A Windows version written in Visual Basic, and set in St. Louis. Source code available on request.
- [DopeWars for MacOS](http://www.likelysoft.com/dopewars/) (Likely Software). Available for MacOS 8, 9, and OS X. Shareware; registration required.
- [The original MS-DOS Dopewars](http://www.abandonkeep.com/games.php?GameID=268) (Happy Hacker Foundation).
- [Drug Wars](http://www.angelfire.com/ca/Dopewars/). John Dell's original MS-DOS game.
- [Drug Lord](http://aw.localhost.ee/aw/view/573.html). An old MS-DOS version.
- [Drug Lord 2.1](http://www.geekhideout.com/druglord2.shtml). A free Windows version.
- [DopeWars for PalmOS](http://pdaguy.com/dopewars/). Matt Lee's classic PalmOS version. Freeware, with source code.
- [Dopewars for PocketPC](http://dopewars.scum.dk/). Freeware, with source code.
- [Dopewars for Blackberry](http://dopewarsbb.sourceforge.net/).
- [Dopewars for Psion](http://www.palmanac.co.uk/) (Palmanac Software). Available for the Psion Series 5 or Series 7.
- [Dope Mart](http://www.dopemart.com/). An online version of the game.
- [Java Dope Wars](http://www.cs.helsinki.fi/u/iizuka/games/dopewars/index.html). Another online version.
- [eDrugTrader](http://www.edrugtrader.com/). Online multi-player version.
- [Online dopewars](http://www.drunkmenworkhere.org/185.php). Another online multi-player version, which is closely based on the dopewars from this site.
- [Dope Wars for MIDP](http://www.redteam.co.uk/dopewars/) (RedTeam). For playing dopewars on your mobile phone.
- [DopeWars for the Amiga](http://www.amidev.50megs.com/dopewars.html)
- [dopewars in Perl](http://opop.nols.com/proggie.html)

**All of a sudden the game just stops for no reason, and I have to restart. What's going on?**

You only get a month (31 days) to make your fortune; after this your time is up!

**31 turns isn't long enough. How do I get a longer game?**

Edit the [configuration file](https://dopewars.sourceforge.io/docs/configfile.html), and add a line of the form NumTurns=x where x is the number of turns. Alternatively, you can edit this file by selecting "Options" from the "Game" menu of the Windows or GTK+ dopewars client, of version 1.5.4 or later. If you are connecting to a public dopewars server, however, the number of turns is set by whoever runs the server, and you cannot change it.

**The game could do with some sounds or extra graphics - can you add them?**

I can't draw, and don't have access to a recording studio. If, however, you can provide suitable sounds or graphics, I will be only too happy to incorporate them into the game. (Note that the sounds and graphics need to be your own work - copying them from a game or other copyrighted source is no good.)

**The game segfaults all the time when I try to page or talk to other players! I'm using the latest RPM.**

You're probably running the binary on a system with different C libraries to my Linux box. Try getting the SRPM or tarball and building that to see if it fixes your problem.

**Do I _really_ need GLib to build dopewars from the source code? I just want to use the text-mode client.**

I'm afraid so. It's true that GLib was originally developed as part of the GTK+ toolkit for the GIMP, but it is **not** a graphics library; it's a general purpose utility library. dopewars uses it for string handling, config file parsing, memory allocation, error handling, logging, list types, Windows/Unix portability, and Unicode support. So yes, you do need it! It's not a particularly big library, anyway.

**I've found a bug! Fix it please.**

[Open an issue](https://github.com/benmwebb/dopewars/issues). Make sure you leave details of the dopewars version you're using (e.g. 1.5.2) and your system (e.g. RedHat Linux 7.2, Windows 10). The more details you can give about how and when the bug occurred, the more likely that it can be fixed. necessary.

**Can you add _&lt;feature&gt;_ ?.**

dopewars is open source software, so there's nothing to stop you from getting the source code, adding the feature yourself, then submitting a [pull request](https://github.com/benmwebb/dopewars/pulls). Alternatively, [open an issue](https://github.com/benmwebb/dopewars/issues) so that developers can keep track of all desired new features.

[Main Index](https://dopewars.sourceforge.io/) : FAQ

 [![Valid CSS](https://dopewars.sourceforge.io/valid-css.png)](https://jigsaw.w3.org/css-validator/validator?uri=https://dopewars.sourceforge.io/faq.html)[![Valid XHTML 1.1](https://dopewars.sourceforge.io/valid-xhtml11.png)](https://validator.w3.org/check?uri=https://dopewars.sourceforge.io/faq.html)[![Fast, secure and Free Open Source software downloads](https://sflogo.sourceforge.net/sflogo.php?group_id=11128&type=12)](https://sourceforge.net/projects/dopewars)[Edit on GitHub](https://github.com/benmwebb/dopewars-website/blob/main/faq.php) Written by [Ben Webb](mailto:benwebb@users.sf.net)  
This page last updated: Mon Jun 27 6:51:47 UTC 2022
