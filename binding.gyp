{
  "targets": [
    {
       "target_name": "node-osx-mediacontrol-itunes",

       "sources": [ "iTunes.h", "itunes.mm" ],

       "include_dirs": [
		"src",
		"System/Library/Frameworks/ScriptingBride.framework/Headers",
		"<!(node -e \"require('nan')\")"
	],

       "link_settings": {
		"libraries": [
			"-framework CoreFoundation",
			"-framework ScriptingBridge",
			"-framework Foundation"
		]
	}
    }
  ]
}
