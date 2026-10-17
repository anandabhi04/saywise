# Appearance checks

`light/` and `dark/` contain window captures of all six main pages for T9:
Home, History, Dictionary, Snippets, App styles and Settings.

Launch the Debug app with either appearance:

```sh
open build/DerivedData/Build/Products/Debug/Saywise.app --args -SaywiseAppearance light
open build/DerivedData/Build/Products/Debug/Saywise.app --args -SaywiseAppearance dark
```

Quit between launches. With no argument, windows follow the Mac's appearance.
The floating widget keeps its own dark appearance.

Each PNG was captured with `screencapture -x -l <windowID> <file>` after
selecting its sidebar page. The captures show the current local data while
models are loading. Settings and App styles scroll to additional sections.

T8 uses `App/AppIcon.icon`, with SVG masters in `docs/design/icon/`.
The required Debug build passed with Xcode 26.6. Its `Saywise.app` contains
`AppIcon.icns` and `Assets.car`; `CFBundleIconFile` and `CFBundleIconName`
both name `AppIcon`. The compiled catalog contains Aqua and Dark Aqua
icon stacks. ChirpCore passed 115 tests in 15 suites. No bench was run for T8/T9.
