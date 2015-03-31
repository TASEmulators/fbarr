

# Record the action to an FBM #

![https://fbarr.googlecode.com/svn/wiki/FBA-AVI1.png](https://fbarr.googlecode.com/svn/wiki/FBA-AVI1.png)

Click, then write the name of the file, which will go in your _recordings_ folder.

If you want a clip and not a whole TAS, make sure the FBM starts from savestate by **unchecking** "Record from Power-On".

![https://fbarr.googlecode.com/svn/wiki/FBA-AVI2.png](https://fbarr.googlecode.com/svn/wiki/FBA-AVI2.png)

Now as you play the game the inputs will get recorded to the FBM.

If the action was recorded in a [MacroLua script](http://code.google.com/p/macrolua/), it's still recommended to convert to FBM before making a video. Do this by pausing the emulator, starting playback of the script, starting FBM recording, and then unpausing.

When you have recorded as much as you want, end it with _Game > Movie... > Stop movie_

# Make FBA dump the video #

Pause the emulator and start the FBM with _Game > Movie... > Start playback..._

Start dumping the video with _Game > Movie... > Record AVI..._

Pick a name and location for the AVI. Next you must select the video compression.

![https://fbarr.googlecode.com/svn/wiki/FBA-AVI3.png](https://fbarr.googlecode.com/svn/wiki/FBA-AVI3.png)

The options available here depend on the codecs installed. You can use _Full Frames (Uncompressed)_ for a perfect video that requires no codecs, but the file will be very large. You may prefer a lossless codec such as _FFV1_ or _H.264 lossless_, which are options included in [ffdshow](http://www.free-codecs.com/download/FFDShow.htm). Other lossless options are [Lagarith](http://www.free-codecs.com/download/CamStudio_Lossless_Codec.htm) and [CamStudio](http://www.free-codecs.com/download/Lagarith_Lossless_Video_Codec.htm). Using a lossy codec like DivX will reduce the quality and is not recommended. Once you've picked your codec you may need to click _Configure..._ to get the options set up to your preference. These options will depend on the codec.

![https://fbarr.googlecode.com/svn/wiki/FBA-AVI4.png](https://fbarr.googlecode.com/svn/wiki/FBA-AVI4.png)

When everything is set up, click _OK_ in the Video Compression window to begin the dumping, then unpause FBA. Don't worry if the game runs too slow while recording. The AVI will play at full speed. FBA will pause automatically when the FBM comes to an end. You can record extra by unpausing and waiting. Finalize the process by selecting _Game > Movie... > Stop AVI_ from the menu. The AVI will be split into 2 GB segments if necessary.

The rest is up to your editing and encoding software.