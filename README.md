<p align="center"> 
  <img src="https://github.com/mmick66/kinieta/blob/master/Kinieta_Logo.png">
</p>

## Kinieta
An Animation Engine for iOS with an Intuitive API and Readable Code! (Written in Swift 4.0.)

## Why another?

I decided to build an Animation Engine from scratch for the usual reason: No other did what I wanted **how** I wanted it! While there are some great libraries out there, my requiremenets where pretty restrictive as what I wanted was:

* A library written in **Swift 4.0**
* With a **timeline** approach where animations can run in **parallel** at different start and end points
* The ability to **group** various animations from different views with a single complete block
* A **simple API** where I could just throw in some variables and the rest would be dealt by the library
* A **convention over configuration** approach where many variables would be assumed when not passed
* Efficient interpolation with infinite **easing functions** based on custom Bezier curves
* Provides **real color interpolation** using the advanced HCL color space rather than plain RGB
* Code that was **extremely** easy to read and new developers from the community could join in in no time!

## Installation

For the moment, just copy the files in the Kinieta (virtual) folder

## How to Use

```swift
square.move(to: ["x": 374], during: 1.0).easeInOut(.Back).wait(for: 1.0).complete {
    square.move(to: ["x": 74])
}
```

![Basic Move with Ease](https://github.com/mmick66/kinieta/blob/master/Assets/move.easeInOut.Back.gif)

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
aView.move(to: ["x": 250, "y": 500], during: 0.5).delay(for: 0.5).easeInOut(.Back).complete { print("♥") }
```

The UIView properties that can be animated, together with their keys are:


| Key                       | Value Type    |   Metric    | Property Animated  |
| -------------             |:-------------:|:-------------:|               -----:|
| **"x"**                       | Any Numeric   | screen points |   `frame.origin.x` |
| **"y"**                       | Any Numeric   | screen points  |  `frame.origin.y` |
| **"w"** or **"width"**            | Any Numeric   |  screen points |`frame.size.width` |
| **"h"** or **"height"**           | Any Numeric   | screen points |`frame.size.height` |
| **"a"** or **"alpha"**            | Any Numeric   |  0 to 1 transparency |           `alpha` |
| **"r"** or **"rotation"**            | Any Numeric   |  **degrees** |           `transform` |
| **"frame"**                   | CGRect        |  composite  |         `frame` |
| **"bg"** or **"background"**      | UIColor       | color |  `backgroundColor` |
| **"brc"** or **"borderColor"**    | UIColor       | color |`layer.borderColor` |
| **"brw"** or **"borderWidth"**    | UIColor       | screen points |`layer.borderWidth` |
| **"crd"** or **"cornerRadius"**   | UIColor       | bevel radius | `layer.cornerRadius` |

Note: When two synonymous keys (like "bg" and "background") are passed in the same list the most **verbose** (ie. "background") will win over and the other will be silently ignored.

### Easing

Every move can be smoothed by calling one of the 3 easing functions and pass:

```swift
// When no curve is passed `.Quad` is used
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeIn()

// Ease at start, end and both ends respectively
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeIn(.Cubic)
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeOut(.Cubic)
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeInOut(.Cubic)
```

An default argument can be passed to provide an easing functions to be used, Quad being the default. All easing is based on Bezier curves and many are provided by default as seen in the `Easing.Types` enum. 

```swift
enum Types {
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
 
 All the curves passed are **prebaked** into tables for fast resolution!

### Sequencing

You can string a few animations together very easily:

```swift
let start = ["x": aView.x, "y": aView.y]
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeInOut(.Cubic)
     .move(to: ["x": 300, "y": 200], during: 0.5).easeInOut(.Cubic)
     .move(to: start, during: 0.5).easeInOut(.Cubic)
```

The dictionary with the animations can be saved and passed later as the example above shows. You can also add a pause between animations by calling the `wait(for time: TimeInterval)` function:

```swift
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeInOut(.Cubic)
     .wait(for: 0.5)
     .move(to: ["x": 300, "y": 200], during: 0.5).easeInOut(.Cubic)
```

Finally, you can repeat the animation sequence with the `again(times: Int = 1)` function.

```swift
aView.move(to: ["x": 250, "y": 500], during: 0.5).easeInOut(.Cubic)
     .move(to: ["x": 300, "y": 200], during: 0.5).easeInOut(.Cubic)
     .again()
```

### Parallelizing

You can run various animations together to achieve more complicated effects. For example, we can add a short fade at the end of a move and have a single callback when everything finishes:

```swift
aView.move(to: ["x": 200, "y": 500], during: 1.0).easeInOut(.Cubic)
     .move(to: ["a": 0], during: 0.2).delay(for: 0.8).easeOut()
     .parallel()
     .complete { print("Finished All") }
```

 ![Move with Custom Ease](https://github.com/mmick66/kinieta/blob/master/Assets/move.easeInOut.fade.gif)
 
 #### Potential Pitfalls in Combining Groups
 
 What `.parallel()` does is to create an internal group with all the actions **that preceded the call** added inside. This might cause a problem when two or more parallel groups need to be run sequencially. For example:
 
 ```swift
aView.move(to: ["x": 300], during: 1.0).easeInOut() // this needs to run first,
     .move(to: ["x": 200], during: 1.0).easeInOut() // then this...
     .move(to: ["a": 0], during: 0.2).easeOut()     // ...parallel with this!
     .parallel()
```

The code above will take **all three moves** and run then in parallel, esentially ignoring the first. What we wanted however is for the first move to run on its own **followed** by the other 2 in parallel. To achive this we call the `then` property as follows:

 ```swift
aView.move(to: ["x": 300], during: 1.0).easeInOut() 
     .then        
     .move(to: ["x": 200], during: 1.0).easeInOut() 
     .move(to: ["a": 0], during: 0.2).easeOut()     
     .parallel()
```
 
 ### Grouping
 
 You can group multiple animation of different views and get a common complete handler when they all finish.
 
 ```swift
 Engine.shared.group([
     aView.move(to: ["x": 374], during: 1.0).easeInOut(.Cubic)
          .move(to: ["a": 0], during: 0.2).delay(for: 0.8).easeOut().parallel(),
     otherView.move(to: ["x": 100, "r": 30], during: 1.0).easeInOut(.Cubic)
]) { print("Both Finished") }
```

Remember that calls to the Kinieta API return an object so one could also do:

 ```swift
 let move1 = aView.move(to: ["x": 374], during: 1.0).easeInOut(.Cubic)
 let move2 = otherView.move(to: ["x": 100, "r": 30], during: 1.0).easeInOut(.Cubic)
 Engine.shared.group([move1, move2]) { print("Both Finished") }
```
