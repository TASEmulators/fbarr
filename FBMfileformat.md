fbm is the current movie capture format used by Final Burn Alpha rerecording (FBA-rr)

It is almost identical to the earlier fr format used by blip's rerecording build.
FBM file format description
FBM file consists of a header, followed by an optional save state chunk, followed by a frame data chunk, then a metadata chunk.

```
File Header format:

    000 4-byte signature: 46 42 31 20 "FB1 "
    004 1-byte unsigned int: version number (for now it is always 2)

Save State Chunk format:

    000 4-byte chunk identifier: 46 53 31 20 "FS1 "
    004 4-byte little-endian unsigned int: size of this save state chunk in bytes, not including the chunk identifier
    008 4-byte little-endian unsigned int: version of FB this was saved from
    00C 4-byte little-endian unsigned int: minimum FBA version required to load NV data
    010 4-byte little-endian unsigned int: minimum FBA version required to load All data
    014 4-byte little-endian unsigned int: size of the compressed saved data (not including header size or padding)
    018 32-byte possibly-unterminated ASCII string: Name of the game
    038 4-byte little-endian unsigned int: number of frames that have already been emulated before recording started
    03C 12 bytes: reserved, set to 0
    048: the compressed save data

Frame Data Chunk format:

    000 4-byte chunk identifier: 46 52 31 20 "FR1 "
    004 4-byte little-endian unsigned int: size of this frame data chunk in bytes, not including the chunk identifier
    008 4-byte little-endian unsigned int: number of recorded frames
    00A 4-byte little-endian unsigned int: rerecord count
    00E 12 bytes: reserved, set to 0
    01A: frame input data. The format varies depending on which inputs the game supports and may be compressed (unknown).
         Reset is always a possible input, although the value that means Reset will be different depending on the game.

Meta Data Chunk format:

    000 4-byte chunk identifier: 46 52 31 20 "FRM1"
    004 4-byte little-endian unsigned int: size of the metadata in bytes, not including the chunk identifier or this integer
    008 string of little-endian 2-byte wide characters of locale-dependant encoding: author information
```
Notes
The format does not indicate a framerate, but it is assumed to always be 60 frames per second.