# Purpose
This project is nothing more than my making a personal set of tools available to others who have similar needs but
without the time or background to satisfy them.  I've been an Audible user for many years and have many hundreds of
books containing thousands of bookmarks.  These combine to call for more functionality.

## How to use the tools
I choose PowerShell because it's trivially available on all platforms where [Libation](https://github.com/Mbucari/Libation)  runs and requires no additional 
tools to accomplish it's goal or be maintained.  In general:

1) Download the appropriate .ps1 file
2) Execute it from a PowerShell command prompt.  All the scripts support help.

    help ./Convert-LibationToSabp.ps1 -full

As an example, after downloading LibationToSabp.ps1, the above command should describe exactly what the script does,
which parameters are required and what optional parameters are available to influence your specific results.

# Convert-LibationToSabp.ps1

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

I did have a list here but I've since created an [AudioBookShelf](https://audiobookshelf.org/) and started using the [Absorb](https://github.com/pounat/absorb) UI I've given up working to make Smart AudioBook player have better bookmark support.

AudioBookShelf has huge advantages when it comes to bookmarks and so I'm in the process of finding a way to import the thousands I have to the AudioBookShelf DB.
The UI you choose to use with AudioBookShelf is not, as far as I know, important.  I just mentioned the one I choose in case you're interested.
If/when I get the conversion done I'll create a repository here with how I did it unless it's terribly messy.

The timestamp conversion in AudioBookShelf WAS A MESS!  I wanted the AudioBookShelf to be able to list books in the order I acquired them.
Although this is easy in Libation because it knows the purchase dates, AudioBookShelf gives no mechanism to set the createdAt value.
The closest you could possibly come is to place books in your directory structure one-by-one, doing an import on each one (800 times? I don't think so).
Since you imported them in order and it's possible to display in import order you come close but wouldn't have the actual purchase date.
I ended up querying the real dates from the Libation db along with the ASIN.
Then, because the AudioBookShelf DB doesn't contain the ASIN, I had to connect to its API to map their internal ID to the ASIN.
Then I could build sql update statements to set the internal ID createdAt to the purchase date.
Updates were then issued one by one via a script built from merging the two sets of data.  YUCK


# Split-ByHierarchy.ps1

Although I came up with this for Smart AudioBook player, It looks like it might work for AudioBookShelf.
Basically, audiobooks that are austensibly anthologies are typically arranged within Libation metadata as a hierarchy of chapters.
When this is true, breaking out the first level of hierarchy into separate directories should be relatively easy.  
The proposed tool, by moving groups of chapters into subdirectories, would allow one to access top level collections of chapters as
stand-alone books.

Since I haven't actually started, I'm not yet sure how this will interact with LibationToSabp when it comes to personal bookmarks.

Feel free to make suggestions.
