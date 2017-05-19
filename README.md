## node-osx-mediacontrol

This module allows to control iTunes and Spotify on macOS; it is possible to register a callback to be notified of the app's state.

For now, only iTunes is implemented with the functionality: 

    * Receive status updates (playback state changes)
    * Control play, Control pause

Example usage:

```sh

  const MediaControl = require('node-osx-mediacontrol');
   
  ...

  /* Registers to listen to iTunes events */
  MediaControl.iTunes.observe(function(state) {
    
	switch (state) {
	    case MediaControl.ITUNES_STOPPED:
		/* do something */
		break;
	    case MediaControl.ITUNES_PLAYING;
		/* do something */
		break;
	    case MediaControl.ITUNES_PAUSED:
		/* do something */
		break;
  });

  MediaControl.iTunes.controlPause();

  MediaControl.iTunes.controlPlay();

  /* This will stop the module from listening to iTunes events */
  MediaControl.iTunes.ignore();

```
