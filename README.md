<p align="center"> 
  <img src="https://github.com/mmick66/kinieta/blob/master/Kinieta_Logo.png">
</p>

## Kinieta
An Animation Engine for iOS with an Intuitive API and Readable Code! (Written in Swift 4.0.)

```swift
square.move(to: ["x": 374], during: 1.0).easeInOut(.Back).wait(for: 1.0).complete {
    square.move(to: ["x": 74])
}
```

![Basic Move with Ease](https://github.com/mmick66/kinieta/blob/master/Assets/move.easeInOut.Back.gif)

## Why another?

I decided to build an Animation Engine from scratch for the usual reason: No other did what I wanted **how** I wanted it! While there are some great libraries out there, my requiremenets where pretty restrictive as what I wanted was:

* A library written in **Swift 4.0**
* With the ability to **group** various animations into an entity with a  signle complete block
* A **simple API** where I could just throw in some variables and the rest would be dealt by the library
* Efficient interpolation with an infinite amount of **custom easing functions** based on Bezier curves
* Code that was extremely easy to ready so that new developers from the community could join in

## Installation

For the moment, just copy the files in the Kinieta (virtual) folder

## How to Use

### Basic Usage

An extension on `UIView` that is included in the code will provide the entry point for the animations. The interface object is the `Kinieta` and there is one for every view.

```swift
// This will snap the view to the given coordinates
aView.move(to: ["x": 250, "y": 500])

// This will animate the same view to the coordinates in 0.5 seconds
aView.move(to: ["x": 250, "y": 500], during: 0.5)

// This will delay the start of the animation by 0.5 seconds
aView.move(to: ["x": 250, "y": 500], during: 0.5).delay(for: 0.5)

// And this will ease the whole thing
aView.move(to: ["x": 250, "y": 500], during: 0.5).delay(for: 0.5).easeInOut()

// While this will ease it with a bounce-back
aView.move(to: ["x": 250, "y": 500], during: 0.5).delay(for: 0.5).easeInOut(.Back)

// And call the complete block when the animation is finished
aView.move(to: ["x": 250, "y": 500], during: 0.5).delay(for: 0.5).easeInOut(.Back).complete { 
    print("Finished") 
}
```



The UIView properties that can be animated, together with their keys are:
* "x" - the x coordinate as in the `frame.origin.x`
* "y" - the y coordinate as in the `frame.origin.y`
* "w" or "width" - the width as in the `frame.size.width`
* "h" or "height" - the height as in the `frame.size.height`
* "r" or "rotation" - the rotation of the view changing the parameters in the transform matrix
* "a" or "alpha" - the `alpha` property of the view 
* "bg" or "background" - the `backgroundColor` property of the view 
* "brc" or "borderColor" - the borderColor as in the `layer.borderColor`
* "brw" or "borderWidth" - the borderWidth as in the `layer.borderWidth`
* "crd" or "cornerRadius" - the cornerRadius as in the `layer.cornerRadius`

### Easing

Every move can be smoothed by calling the ease functions:

```swift
func easeIn(_ type: Easing.Types = Easing.Types.Quad) -> Kinieta
func easeOut(_ type: Easing.Types = Easing.Types.Quad) -> Kinieta
func easeInOut(_ type: Easing.Types = Easing.Types.Quad) -> Kinieta
```

An default argument can be passed to provide an easing functions to be used, Quad being the default. All easing is based on Bezier curves and many are provided by default as seen in the `Easing.Types` enum. 

```swift
enum Types {
    case Linear
    case Sine
    case Quad
    case Cubic
    case Quart
    case Quint
    case Expo
    case Back
    case Custom(Bezier)
}
 ```
 
The last type `.Custom` will capture a custom Bezier curve and use that as an easing function. A 3rd degree (or cubic) Bezier curve is composed of 4 points called control points. The first and last is by convetion (0.0, 0.0) and (1.0, 1.0) while the other 2 define the curvature. You will not have to figure out these numbers by hand of course as they are useful tools throughout the web to help with that, [cubic-bezier](http://cubic-bezier.com/) being one of them. 

For example, for a very fast start and sudden slow down animation I used [this curve](http://cubic-bezier.com/#.16,.73,.89,.24) as taken from the site, and plugged the numbers in a Bezier instance:

```swift
let myBezier = Bezier(0.16, 0.73, 0.89, 0.24)
aView.move(to: ["x": 250, "y": 500], during: 1.0).easeInOut(.Custom(myBezier))
 ```
 
 ![Move with Custom Ease](https://github.com/mmick66/kinieta/blob/master/Assets/move.easeInOut.Custom.gif)

### Sequencing

You can string a few animations together very easily:

```swift
let start = ["x": aView.x, "y": aView.y]
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeInOut(.Cubic)
     .move(to: ["x": 300, "y": 200], during: 0.5).easeInOut(.Cubic)
     .move(to: start, during: 0.5).easeInOut(.Cubic)
```

You can also add a pause between animations by calling the `wait(for: time)` function:

```swift
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeInOut(.Cubic)
     .wait(for: 0.5)
     .move(to: ["x": 300, "y": 200], during: 0.5).easeInOut(.Cubic)
```

The dictionary with the animations can be saved and passed later as the example above shows.

### Grouping

You can group various animations together to achieve more complicated effects. For example, we can add a short fade at the end of a move and have a single callback when everything finishes:

```swift
aView.move(to: ["x": 200, "y": 500], during: 1.0).easeInOut(.Cubic)
     .move(to: ["a": 0], during: 0.2).delay(for: 0.8).easeOut()
     .group()
     .complete { print("Finished") }
```

 ![Move with Custom Ease](https://github.com/mmick66/kinieta/blob/master/Assets/move.easeInOut.fade.gif)
