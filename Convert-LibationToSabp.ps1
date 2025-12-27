<#
.SYNOPSIS
   Reads the Libation configuration to retrieve metadata about downloaded books.
   Generates bookmarks.sabp.xml for any distinct downloaded book entry directory.

.PARAMETER ConfigPath
   Path to the directory containing Setings.json and FileLocationsV2.json.
.PARAMETER IdList
   Defaults to * (all). Otherwise, you can provide a list of Audible IDs.
.PARAMETER SkipExisting
   When false, existing bookmark files are regenerated and overwritten if existing.
.PARAMETER PreferMono
   Ignored unless both split and monolithic audio files exist.
   Split format is preferred by default when both styles are present.
.PARAMETER AssumeTrim
   Adjusts all bookmark times to assume audio file(s) were stripped of Audible branding.
   Defaults to the Libation config setting StripAudibleBrandAudio
.PARAMETER TitleFormat
   Legal values are Title, Subtitle and Mixed
   'Title' yields nested chapters A.B.C.D as Title=A & Subtitle=B|C|D
   'Subtitle' yields D & C | B | A and 'Mixed' yields D & A | B | C.
.PARAMETER ChapterSeparator
   The default is ' | '. For example Part II | Chapter 4. Used by TitleFormat
.EXAMPLE
    ./Convert-LibationToSabp.ps1 '~/.local/share/Libation/'

    This example processes all downloaded books.
    Book directories with an existing bookmarks.sabp.xml file are skipped.
.EXAMPLE
    ./Convert-LibationToSabp.ps1 '~/.local/share/Libation/' -IdList B0CRBKZLD5,B0CY7BVTW9,B094X2RN1F,B09WB2V33H,B01L2PE1XI

    This example updates bookmarks for the listed books only. Existing bookmark files are overwritten.
#>

[CmdletBinding(SupportsShouldProcess=$false)]
param([parameter(Mandatory=$true)]
       [string] [ValidateScript({Test-Path $_ -PathType container})] $ConfigPath,
       [string[]]                                                    $IdList           = "*",
       [boolean]                                                     $SkipExisting     = $false,
       [boolean]                                                     $PreferMono       = $false,
       [boolean]                                                     $AssumeTrim       = $false,
       [string] [ValidateSet('Title','Subtitle','Mixed')]            $TitleFormat      = 'Title',
       [string]                                                      $ChapterSeparator = ' | ',
       [boolean]                                                     $Quiet            = $false
     )

# block is for testing
<#                     # B094X2RN1F is megacollection, B09WB2V33H is Monsters6
$ConfigPath            = '~/.local/share/Libation/'
$IdList                = 'B0CRBKZLD5','B01L2PE1XI','B0CY7BVTW9','B094X2RN1F','B09WB2V33H'
$SkipExisting          = $true
$PreferMono            = $false
$AssumeTrim            = $false
$TitleFormat           = 'Title'
$ChapterSeparator      = ' | '
#>

# Static strings
$LocationDataFilename  = 'FileLocationsV2.json'
$MainSettingsFilename  = 'Settings.json'
$MetaDataSuffix        = '.metadata.json'
$BookmarkSuffix1       = '.json'
$BookmarkSuffix2       = ' - Records.json'
$OutputFileName        = 'bookmarks.sabp.xml'

# Build the actual list of bookmarks to be written
Function Build-SabpList($BookData) {
  $AudioFileList= $BookData.LocationData.AudioFileList
  $ChapterData  = $BookData.ChapterInfo
  $Chapters     = $ChapterData.chapters
  $Bookmarks    = $BookData.UniqueBookmarks
  $BookmarkList = New-Object System.Collections.Generic.List[PSCustomObject]
  $TrimAdjust   = $ChapterData.AssumeTrim?$ChapterData.brandIntroDurationMs:0
  $Index = 0

  # Index 0 is a monolithic file.  Chapterized files start with 1. Find first/only file
  If(!($BookData.CreateMonolithic)) {
    foreach ($file in $AudioFileList) {
      if ($file.Index -eq 1) { break }
      $Index++
    }
  }
  # each chapter gets a bookmark so user bookmarks can be interleaved
  $Chapters|%{
    $JustFilename = Split-Path $AudioFileList[$Index].Path -leaf
    If(!($BookData.CreateMonolithic)) {
      $Index+=1
    }
    $Position = [int](($_.start_offset_ms - $TrimAdjust)/1000)
    [PSCustomObject]@{
      chapterMark  = $true
      title        = $_.title
      description  = $_.subtitle
      fileName     = $JustFilename
      filePosition = $Position -lt 0?0:$Position
    }}|%{$BookmarkList.Add($_)}

  # if there are any user bookmarks, interleave them
  if($Bookmarks.count) {
    $Bookmarks|%{
      $Position = [int]((([TimeSpan]::parse($_.Start)).TotalMilliseconds - $TrimAdjust)/1000)
      [PSCustomObject]@{
        chapterMark  = $false
        title        = $_.Title
        description  = $_.Text
        fileName     = ''
        filePosition = $Position -lt 1?1:$Position
        dateCreated  = $_.Created
      }}|%{$BookmarkList.Add($_)}
  }
  # sort them
  $BookmarkList = $BookmarkList|Sort-Object filePosition

  # Monolithic audio already has correct time offsets and the filename is static
  # For chapterized, user bookmarks must get correct filename and adjusted start-time
  # Also, chapterized books don't get bookmarks per chapter since it's done at file level
  $NewList = New-Object System.Collections.Generic.List[PSCustomObject]
  if($Bookmarks.count) {
    $LastChapter = [PSCustomObject]@{}
    $BookmarkList|%{
      If ($_.chapterMark) {
        $LastChapter = $_
        If($BookData.CreateMonolithic) {
          $_
        }
      }
      Else {
        $Position = $_.filePosition-($BookData.CreateMonolithic?0:$LastChapter.filePosition)
        [PSCustomObject]@{
          chapterMark  = $_.chapterMark
          title        = $_.title
          description  = $_.description
          fileName     = $LastChapter.fileName
          filePosition = $Position
          dateCreated  = $_.dateCreated
        }}
    }|%{$NewList.add($_)}
  }
  $BookmarkList = $NewList

  Return $BookmarkList
}

# Collects the data required to build the list then builds and writes it
Function Build-SabpXml ($BookID){
# $BookID = 'B002V1O7D2'        # allows testing
  $BookData = Get-BookMetadata $BookID
  # Assume any error collecting data has already been reported
  if(!$BookData){Return}
  $OutFile  = $BookData.LocationData.SabpFilename
  $SabpList = Build-SabpList $BookData
  $Result   = Convert-ToBookmarkXML $SabpList
  $Type     = $BookData.CreateMonolithic?"Monolithic ":"Chapterized"
  Write-Host "Creating $Type-{$BookID}: $OutFile"
  $Result.Replace('encoding="utf-16"','encoding="UTF-8"') | `
    Out-File -LiteralPath $OutFile -Encoding utf8
}

function Convert-ToBookmarkXML ([array]$BookmarksData) {
  # Set up XML writer settings (for indenting)
  $xmlWriterSettings = New-Object System.Xml.XmlWriterSettings
  $xmlWriterSettings.Indent = $true
  $xmlWriterSettings.IndentChars = "  "

  # Create a string writer and an XML writer
  $xmlStream = New-Object System.IO.StringWriter
  $xmlWriter = [System.Xml.XmlWriter]::Create($xmlStream, $xmlWriterSettings)

  # Write the XML declaration and start the <root> element
  $xmlWriter.WriteStartDocument()
  $xmlWriter.WriteStartElement("root")

  # Loop through each bookmark object
  foreach ($bookmark in $BookmarksData) {
    $xmlWriter.WriteStartElement("bookmark")

    # Write the elements for each bookmark
    $xmlWriter.WriteElementString("title", $bookmark.title)
    $xmlWriter.WriteElementString("description", $bookmark.description)
    $xmlWriter.WriteElementString("fileName", $bookmark.fileName)
    $xmlWriter.WriteElementString("filePosition", $bookmark.filePosition.ToString())
    if($bookmark.dateCreated) {
      $xmlWriter.WriteElementString("dateCreated", $bookmark.dateCreated?.ToString())
    }
    $xmlWriter.WriteEndElement() # Close the <bookmark> element
  }

  # Close the <root> element and the document
  $xmlWriter.WriteEndElement() # Close the <root>
  $xmlWriter.WriteEndDocument()

  # Output the XML content as a string
  $xmlWriter.Flush()
  $xmlStream.ToString()
}


Function Get-BookmarkData($FileBaseName) {
  # Prioritize manually retrieved bookmark file over the one added during audio download
  $BookmarkFilename = $FileBaseName+$BookmarkSuffix2
  If (!(Test-Path -LiteralPath $BookmarkFilename)) {
    $BookmarkFilename = $FileBaseName+$BookmarkSuffix1
    If (!(Test-Path -LiteralPath $BookmarkFilename)) {
      # Simulate a file without any bookmarks if the file doesn't exist
      # since these (if any) are added to chapter bookmarks
      [PSCustomObject]@{records = @()}
      Return
    }
  }
  Get-JsonObject $BookmarkFilename
}

Function Get-BookMetadata($BookID){
  # $BookID = 'B094X2RN1F'
  $LocationData = $FileLocations[$BookID]
  # Trying to generate for a book that doesn't have all the needed metadata is impossible
  If (!$LocationData) {
    Write-Host "Skipping '$BookID': ID not found in '$LocationDataFullName'"
    Return
  }
  # Don't bother doing more processing if the output isn't going to be wanted
  If ($SkipExisting -and (Test-Path -LiteralPath $LocationData.SabpFilename)) {
    if (!$Quiet) {
      Write-Host "Skipping '$BookID': -SkipExisting is true and '$($LocationData.SabpFilename)' exists"
    }
    Return
  }
  $FileBaseName     = $LocationData.FileBaseName
  $ChapterFileCount = ($LocationData.AudioFileList|?{$_.Index -gt 0}).Count
  $MonoFileCount    = ($LocationData.AudioFileList|?{$_.Index -eq 0}).Count
  $BookMetadata     = Get-JsonObject $LocationData.MetaDataFileName
  $BookMetadata.ChapterInfo.chapters = Optimize-ChapterInfo $BookMetadata.ChapterInfo.chapters
  $ChapterCount     = $BookMetadata.ChapterInfo.chapters.count
  # When no chapter files, there must be exactly 1 mono file (which is what we will generate bookmarks for)
  if($ChapterFileCount -eq 0 -and $MonoFileCount -ne 1) {
    Write-Host "Skipping '$BookID': Found $MonoFileCount, expecting 1 entry in '$LocationDataFullName'"
    Return
  }
  # Do we build Monolithic? Y/N (vs Chapter style) .sabp format
  $TypeMono = (($PreferMono -and $MonoFileCount -eq 1) -or $ChapterFileCount -eq 0)
  # If we can't (or don't prefer) generating for a mono file then the chapter file count must be correct
  if(!$TypeMono -and ($ChapterFileCount -ne $ChapterCount)) {
    Write-Host "Skipping '$BookID': Found $ChapterCount chapters but $ChapterFileCount filenames in '$LocationDataFullName'"
    Return
  }
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'LocationData' -Value $LocationData
  # Add any bookmarks to the metadata.  Accessed as: $BookmetaData.BookmarkData.records|ft
  $BookmarkData = Get-BookmarkData $FileBaseName
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'BookmarkData' -Value $BookmarkData
  # The above is superfluous.  Maybe I should remove it?
  $UniqueBookmarks = Get-UniqueBookmarks $BookmarkData
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'UniqueBookmarks' -Value $UniqueBookmarks
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'CreateMonolithic' -Value $TypeMono
  # Setting literally lets me determine it some other way later.  Only this value is used by generator
  Add-Member -InputObject $BookMetadata.ChapterInfo -MemberType NoteProperty -Name 'AssumeTrim' -Value $AssumeTrim
  $BookMetadata
}

Function Get-ConfigData($LeafName) {
  $FullPath = (Join-Path $ConfigPath $LeafName)
  Get-JsonObject $FullPath
}

Function Get-JsonObject($FullPath) {
  If(!(Test-Path -LiteralPath $FullPath)) {
    Throw "Required metadata file not found: '$FullPath'"
    Return
  }
  ConvertFrom-Json -InputObject (Get-Content -LiteralPath $FullPath -Raw)
}

# Of the 3 possible versions of a bookmark, this picks the most feature rich of the versions available
Function Get-UniqueBookmarks($BookmarkData) {
  $priority = @{
    Clip     = 1
    Note     = 2
    Bookmark = 3
  }
  # For each unique start time, pick Clip if available, otherwise Note, Bookmark is just a time with no label
  $BookmarkData.records |
    Where-Object { $priority.ContainsKey($_.Type) } |
    Group-Object Start |
    ForEach-Object {
      $_.Group |
        Sort-Object { $priority[$_.Type] } |
        Select-Object -First 1
    }
}

# Chapters can be nested, which .sabp doesn't support.  This implements unwinding options
# This not only unwinds the nesting but determines what parts of the hierarchy are reported where
Function Optimize-ChapterInfo($ChapterList,
                              [string[]]$Hierarchy=@(),
                              [PSCustomObject]$ShortClip=$null){
  $NewList = New-Object System.Collections.Generic.List[PSCustomObject]
  $ChapterList|%{
    $Current = $_
    $NewHierarchy = $Hierarchy + $Current.title
    if($ShortClip -ne $null){
      $Current.title      = $ShortClip.title + $ChapterSeparator + $Current.title
      $Current.length_ms += $ShortClip.length_ms
      $ShortClip          = $null
    }
    # In an anthology with Books that have sections and chapters or other hierarchies A.B.C.D
    # Title is either the current highest level name (Title) or the lowest level name
    # Subtitle is then B | C | D or (Subtitle=) A | B | C or (Mixed=) C | B | A
    Switch ($TitleFormat) {
      'Title'    {
        $Title        = $NewHierarchy[0]
        $Subtitle     = $NewHierarchy[1..10] -join $ChapterSeparator #Arbitrary limit=10. Could use [int]::MaxValue
      }
      'Subtitle' {
        $Title        = $NewHierarchy.Reverse[0]
        $Subtitle     = $NewHierarchy.Reverse[1..10] -join $ChapterSeparator
      }
      'Mixed'    {
        $Title        = $NewHierarchy[-1]
        $Subtitle     = $NewHierarchy.Reverse[1..10].Reverse -join $ChapterSeparator
      }
      default {Throw "Illegal TitleFormat '$TitleFormat'"}
    }
    If ($Current.length_ms -lt 3000)  { # at least one file of 3.0 seconds was found so it must be less than that
      $ShortClip = $Current
    }
    Else {
      $NewList.Add(
        [PSCustomObject]@{
          title            = $Title
          length_ms        = $Current.length_ms
          start_offset_ms  = $Current.start_offset_ms
          start_offset_sec = $Current.start_offset_sec
          subtitle         = $Subtitle
        }
      )
    }
    If($Current.chapters -is [Array]) {
      $NewList.AddRange((Optimize-ChapterInfo $Current.chapters $NewHierarchy $ShortClip))
      $ShortClip = $null
    }
  }
  return ,$NewList
}

# By default, some data isn't needed pdf,cue,,, while other data is far more useful organized differently
Function Optimize-LocationData(){
  Begin {$Result = @{}}
  Process {
    $Groups     = $_.Value | Group-Object { [String]$_.FileType } -AsHashTable
    If ($Groups -and $Groups['0']?.Count -and $Groups['1']?.Count) {
      $MetaData       = @(($Groups['0'].Path|?{$_.Path -like '*'+$MetaDataSuffix})??'')[0].Path
      $BaseName       = $MetaData.SubString(0,$MetaData.Length-$MetaDataSuffix.Length)
      $SabpName       = Join-Path (Split-Path $BaseName) $OutputFileName
      $MaxDigits      = $Groups['1']?.Count.ToString().Length
      $BaseDigits     = Select-FileDigits $MetaData
      $Audio          = @($Groups['1'].Path|%{
                            [PSCustomObject]@{Path=$_.Path
                                              Index=[int](Select-FileDigits $_.Path $BaseDigits $MaxDigits)}})
      $Result[$_.Name]= [PSCustomObject]@{
        FileBaseName     = $BaseName
        MetaDataFileName = $MetaData
        SabpFilename     = $SabpName
        AudioFileList    = $Audio|Sort-Object Index
      }
    }
  }
  End {$Result}
}

# This is the main mechanism used to extract chapter number from chapterized filenames.
# I first use this on the .metadata.json to get BaseDigits: those in every filename.
# Later, by removing these, what remains, if anything, is a chapter number.
# If the chapter name has digits they appear after chapter number and are removed by MaxDigits.
Function Select-FileDigits([string]$FullName,[string]$BaseDigits='',[int]$MaxDigits=0) {
  $L = $BaseDigits.Length
  # First, get the filename sans extension, then remove all non-digit characters
  $T = [System.IO.Path]::GetFileNameWithoutExtension($FullName) -replace '\D'
  # Look for trailing base digits first (leading chapter number probably present)
  If ($L -gt 0 -and $T -like ('*'+$BaseDigits)) {
    $T=$T.Substring(0,$T.Length-$L)
  }
  ElseIf ($L -gt 0 -and $T -like ($BaseDigits+'*')) {
    # Otherwise look for leading base digits (lets trailing chapter number work)
    $T=$T.Substring($L)
  }
  # MaxDigits is 0 only when determining BaseDigits (which will be '')
  # Any chapter name must fall after chapter number (otherwise files wont sort)
  # so truncating at max digits will strip any chapter digits that might exist
  If ($MaxDigits -gt 0 -and $T.length -gt $MaxDigits) {
    $T = $T.Substring(0,$MaxDigits)
  }
  # result is chapter number or base digits: either can be an empty string
  $T
}

<###############################################################################
                        EXECUTION STARTS HERE
 ###############################################################################
#>

$LibationSettings     = Get-ConfigData $MainSettingsFilename
$RawLocationData      = Get-ConfigData $LocationDataFilename
$LocationDataFullName = $(Join-Path $ConfigPath $LocationDataFilename)
$FileLocations        = $RawLocationData.Dictionary.PSObject.Properties | Optimize-LocationData

# SkipExisting defaults to true for * (all) and false for user specified list
If ($IdList[0]??'*' -eq '*') {
  $IdList = $FileLocations.Keys
  # only touch it if the user didn't explicitly give a desired value
  if (!($PSBoundParameters.ContainsKey('SkipExisting'))) {
    $SkipExisting = $true
  }
}

# AssumeTrim defaults to whatever StripAudibleBrandAudio says in Settings.json
  if (!($PSBoundParameters.ContainsKey('AssumeTrim'))) {
    $AssumeTrim = $LibationSettings.StripAudibleBrandAudio
  }


# Process each book
$IdList|%{Build-SabpXml $_}

<# # All this is for testing and debugging
  $BookID = 'B09PSSTFP3'
  $LocationData = $FileLocations[$BookID]
  # Trying to generate for a book that doesn't have all the needed metadata is impossible
  If (!$LocationData) {
    Write-Host "Skipping '$BookID': ID not found in '$LocationDataFullName'"
    Return
  }
  # Don't bother doing more processing if the output isn't going to be wanted
  If ($SkipExisting -and (Test-Path -LiteralPath $LocationData.SabpFilename)) {
    Write-Host "Skippiing '$BookID': -SkipExisting is true and '$($LocationData.SabpFilename)' exists"
    Return
  }
  $FileBaseName     = $LocationData.FileBaseName
  $ChapterFileCount = ($LocationData.AudioFileList|?{$_.Index -gt 0}).Count
  $MonoFileCount    = ($LocationData.AudioFileList|?{$_.Index -eq 0}).Count
  $BookMetadata     = Get-JsonObject $LocationData.MetaDataFileName
  $BookMetadata.ChapterInfo.chapters = Optimize-ChapterInfo $BookMetadata.ChapterInfo.chapters
  $ChapterCount     = $BookMetadata.ChapterInfo.chapters.count
  # When no chapter files, there must be exactly 1 mono file (which is what we will generate bookmarks for)
  if($ChapterFileCount -eq 0 -and $MonoFileCount -ne 1) {
    Write-Host "Skipping '$BookID': Found $MonoFileCount, expecting 1 entry in '$LocationDataFullName'"
    Return
  }
  # If we can't generate for a mono file then the chapter file count must be correct
  if(!($PreferMono -and $MonoFileCount -eq 1) -and ($ChapterFileCount -ne $ChapterCount)) {
    Write-Host "Skipping '$BookID': Found $ChapterFileCount, expecting $ChapterCount entries in '$LocationDataFullName'"
    Return
  }
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'LocationData' -Value $LocationData
  # Add any bookmarks to the metadata.  Accessed as: $BookmetaData.BookmarkData.records|ft
  $BookmarkData = Get-BookmarkData $FileBaseName
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'BookmarkData' -Value $BookmarkData
  # The above is superfluous.  Maybe I should remove it?
  $UniqueBookmarks = Get-UniqueBookmarks $BookmarkData
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'UniqueBookmarks' -Value $UniqueBookmarks
  # Do we build Monolithic? Y/N (vs Chapter style) .sabp format
  $Type = (($PreferMono -and $MonoFileCount -eq 1) -or $ChapterFileCount -eq 0)
  Add-Member -InputObject $BookMetadata -MemberType NoteProperty -Name 'CreateMonolithic' -Value $Type
  # Setting literally lets me determine it some other way later.  Only this value is used by generator
  Add-Member -InputObject $BookMetadata.ChapterInfo -MemberType NoteProperty -Name 'AssumeTrim' -Value $AssumeTrim
  $BookMetadata

  $BookData = $BookMetadata
  # Assume any error collecting data has already been reported
  $OutFile  = $BookData.LocationData.SabpFilename
  $SabpList = Build-SabpList $BookData
  $Result   = Convert-ToBookmarkXML $SabpList
  $Type     = $BookData.CreateMonolithic?"Monolithic":"Chapterized"
  Write-Host "Creating $Type-{$BookID}: $OutFile"
  $Result.Replace('encoding="utf-16"','encoding="UTF-8"') | `
    Out-File -LiteralPath $OutFile -Encoding utf8
#>
