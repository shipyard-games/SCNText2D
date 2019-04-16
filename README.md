# SCNText2D

Rendering text in SceneKit using SDF fonts.

### Features

Currently this framework uses a pre-generated font texture atlas to render 2D text in SceneKit scene. It creates a `SCNGeometry` and configures a material for it for rendering. More examples and features coming in the future. Try out the framework with the included test applications for iOS and macOS.

### TODO

- [x] Take out the font files from the framework and write instructions on including them manually. They grow the binary size of the framework.
- [x] Implement text alignment. Currently text is always left aligned.
- [ ] Add support for tvOS.
- [ ] Figure out what to implement for the v1.0.

### Installing using Carthage

Add this line to your `Cartfile`.

```
github "shipyard-games/SCNText2D" "v0.1.0-alpha"
```

### Running the test applications

The project comes with test applications for iOS and macOS. You can simply run them from Xcode.

![Example](https://pbs.twimg.com/media/D3sU9ZUX4AIvqYn.jpg:large)
