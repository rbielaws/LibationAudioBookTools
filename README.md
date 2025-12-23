# Purpose
This project is nothing more than my making a personal set of tools available to others who have similar needs but
without the time or background to satisfy them.  I've been an Audible user for many years and have many hundreds of
books containing thousands of bookmarks.  These combine to call for more functionality.

## How to use the tools
I choose PowerShell because it's trivially available on all platforms where Libation runs and requires no additional 
tools to accomplish it's goal or be maintained.  In general:

1) Download the appropriate .ps1 file
2) Execute it from a PowerShell command prompt.  All the scripts support help.

    help ./LibationToSabp.ps1 -full

As an example, after downloading LibationToSabp.ps1, the above command should describe exactly what the script does,
which parameters are required and what optional parameters are available to influence your specific results.

# LibationToSabp.ps1

I use books for research as well as entertainment.  Audible doesn't allow me to download my bookmarks,
which typically contain numerous, sometimes extensive notes.   [Libation](https://github.com/Mbucari/Libation) lets me easily retrieve them but
it's an incomplete solution since it's tedious to track and manually download new bookmarks.

By moving to [Smart AudioBook Player](https://play.google.com/store/search?q=smart+audiobook+player&c=apps) I don't need to manually re-load bookmarks every time I create new ones since
they are stored locally in easily read xml format.  But converting requires translating Libation Metadata to
bookmark.sabp.xml.  This tool is my first step.

This tool makes chapter bookmarks available for monolithic downloads and merges any user created bookmarks.
For books split by chapter, only user bookmarks are created.  They point to the correct location of the correct chapter file.
(Or, at least it does the best it can with the meta-data found.  It's not magic!)

## Future plans

Updates I'm considering:
1) Option to exclude chapter or manual bookmarks when they would otherwise be created.
2) Ability to detect .json bookmark source updates from Libation.
3) Ability to merge Libation sourced bookmarks with Smart AudioBook Player created bookmarks
4) Ability to read all the Smart AudioBook Player bookmark files and merge them into a single source.

The main block to merging all Bookmark/Notes is deciding what format to use.  Choices range from tab separated
text to rows in a database.  At the moment I simply merge all the files into a monolithic XML and open it with
the experimental Libreoffice-Calc feature 'XML Source'.  This does not give me anything resembling the ability
to merge notes made within Calc or any other non-xml aware tool, so it's close to useless as-is.  

Feel free to make suggestions.


# SeparateByHierarchy.ps1

I plan to start on this shortly.
Basically, audiobooks that are austensibly anthologies are typically arranged within the metadata as a hierarchy of chapters.
When this is true, breaking out the first level of hierarchy into separate directories should be relatively easy.  
This tool, by moving groups of chapters into subdirectories, would allow one to access top level collections of chapters as
stand-alone books.

Since I haven't actually started, I'm not yet sure how this will interact with LibationToSabp when it comes to personal bookmarks.

Feel free to make suggestions.
