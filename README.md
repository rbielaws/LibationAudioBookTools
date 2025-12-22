                         
   A PowerShell tool that reads the [Libation](https://github.com/Mbucari/Libation) metadata to retrieve information about downloaded books.
   It then generates the bookmarks.sabp.xml file expected by Smart AudioBook Player for downloaded books in
   distinct directories.

  I choose PowerShell because it's trivially available on all platforms where Libation runs and requires no
  additional tools to accomplish it's goal or be maintained.

  This tool makes chapter bookmarks available to monolithic downloads and merges any user created bookmarks.
  For books split by chapter, user bookmarks point to the correct location of the correct chapter file.
  Or, at least it does the best it can with the meta-data found.  It's not magic!
  

This project is nothing more than my making a personal tool available to others who might have similar needs but
without the time or background to solve it.  I've been an Audible user for many years and have many hundreds of
books.  I use books for research as well as entertainment.  Audible doesn't allow me to download my bookmarks,
which typically contain numerous, sometimes extensive notes.  Libation lets me retrieve them but
it's an incomplete solution since it's tedious to track and manually download new bookmarks.

By moving to Smart AudioBook Player I don't need to manually re-load bookmarks every time I create new ones since
they are stored locally in easily read xml format.  But converting requires translating Libation Metadata to
bookmark.sabp.xml.  Version 1.0 of this tool is my first step.

Updates I'm considering:
1) A Quiet option so full updates are not so verbose
2) Option to exclude chapter or manual bookmarks when they would otherwise be created.
3) Ability to detect .json bookmark source updates from Libation.
4) Ability to merge Libation sourced bookmarks with Smart AudioBook Player created bookmarks
5) Ability to read all the Smart AudioBook Player bookmark files and merge them into a single source.

The main block to merging all Bookmark/Notes is deciding what format to use.  Choices range from tab separated
text to rows in a database.  At the moment I simply merge all the files into a monolithic XML and open it with
the experimental Libreoffice-Calc feature 'XML Source'.  This does not give me anything resembling the ability
to merge notes made within Calc or any other non-xml aware tool, so it's close to useless as-is.

Alghough suggestions are welcome, that doesn't mean I'll act, or even respond, although I expect I will try,
if I find a comment useful.
