# WiTT
This is a rewritten version of WiTT, a mod similar to WAILA for Minecraft.
In comparison with the original version by MightyAlex200,

- The selected node is determined more precisely using a raycast (see fbt_core).
- Player preferences are persistent between sessions (using mod storage).
- The WiTT panel has been moved to the top right corner of the screen and given a background.
- There is no option to make the WiTT panel animated.

WiTT stands for "What is This Thing?" and shows the proper and technical names of the node you are currently looking at, as well as its description and image, if it can.

The mod provides a few commands:

- Use `/witt [on | off]` to set whether the WiTT panel should be displayed.
- Use `/witt_liquids [on | off]` to set whether WiTT should show or ignore liquids.

Known issues:

- Minetest uses a variable-width font for HUD, and the length of the background panel has to be guessed based on the number of characters. That means it may show up either too long or too short.
