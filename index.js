
exports.iTunes  = require('./bindings')('node-osx-mediacontrol');

exports.ITUNES_STOPPED  = 0x6b505353 
exports.ITUNES_PLAYING  = 0x6b505350
exports.ITUNES_PAUSED   = 0x6b505370

exports.SPOTIFY_STOPPED = 0x6b505353
exports.SPOTIFY_PLAYING = 0x6b505350
exports.SPOTIFY_PAUSED  = 0x6b505370
