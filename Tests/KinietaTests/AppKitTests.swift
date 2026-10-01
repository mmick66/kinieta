#if os(macOS)
import AppKit
import Testing

@testable import Kinieta

/// AppKit: position, size, rotation, `.alpha`, the layer's colours, border
/// width and corner radius, custom key paths and constraint constants on a layer-backed `NSView`, through
/// the public API, on the engine the UIKit platforms share.
///
/// Frames are stepped by a `ManualFrameDriver`, except in the tests of the
/// real display link and its timer at the bottom.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct AppKitTests {

    // Tests must not depend on the Mac's Reduce Motion switch, which some CI runners have on.
    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    private func makeView() -> NSView {
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        view.wantsLayer = true
        return view
    }

    private func approx(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 1e-6
    }

    @Test(.timeLimit(.minutes(1)))
    func animatesXAndAlphaThroughThePublicAPI() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), .alpha(0), duration: 1).onComplete { completed = true }
        #expect(handle.view === view)

        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 50))
        #expect(approx(view.alphaValue, 0.5))
        #expect(handle.isRunning && !completed)

        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.alphaValue, 0))
        #expect(handle.state == .finished && completed)
        await handle.finished()
    }

    @Test func yMovesTheFrameOriginAndKeepsTheSize() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.y(40), duration: 1)
        frames.step(0.25)
        #expect(view.frame == CGRect(x: 0, y: 10, width: 10, height: 10))
        frames.step(0.75)
        #expect(view.frame == CGRect(x: 0, y: 40, width: 10, height: 10))
    }

    @Test func chainsEasingWaitsAndThen() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate(.x(100), duration: 1).easeIn()
            .wait(0.5)
            .animate(.alpha(0.2), duration: 0.5)
        frames.step(0.5)
        #expect(view.frame.origin.x < 50)  // eased in: behind linear half way
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(0.5)
        #expect(approx(view.alphaValue, 1))  // still waiting
        frames.step(0.25)
        #expect(approx(view.alphaValue, 0.6))
        frames.step(0.25)
        #expect(approx(view.alphaValue, 0.2) && handle.state == .finished)
    }

    @Test func animateTakesADelayAndAnEasing() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let handle = view.animate([.x(100)], duration: 1, delay: 0.5, easing: .in(.cubic))
            .animate(.alpha(0.2), duration: 0.5, delay: 0.5)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 0))  // still delayed
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100 * Easing.in(.cubic).bezier.progress(at: 0.5)))
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        frames.step(0.5)
        #expect(approx(view.alphaValue, 1))  // the second delay
        frames.step(0.25)
        #expect(approx(view.alphaValue, 0.6))
        frames.step(0.25)
        #expect(approx(view.alphaValue, 0.2) && handle.state == .finished)
    }

    @Test func aNewerAnimationTakesThePropertyOver() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let older = view.animate(.x(100), .alpha(0), duration: 1)
        frames.step(0.5)
        view.animate(.x(0), duration: 1)
        frames.step(0.25)
        #expect(approx(view.frame.origin.x, 37.5))  // from the 50 on screen back towards 0
        #expect(approx(view.alphaValue, 0.25))  // the older one keeps alpha
        #expect(older.isRunning)
    }

    @Test func reduceMotionSnapsPositionButFadesAlpha() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        Engine.shared.isReduceMotionEnabled = { true }
        let view = makeView()
        view.animate(.x(100), .alpha(0), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.alphaValue, 0.5))
    }

    /// Where the view's centre is in its superview, whatever its rotation.
    private func centre(of view: NSView) -> CGPoint {
        view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: view.superview)
    }

    private func approx(_ a: CGPoint, _ b: CGPoint) -> Bool {
        approx(a.x, b.x) && approx(a.y, b.y)
    }

    /// A view at (100, 100), 40 by 20, in a 500 point superview.
    private func makeViewInSuperview() -> NSView {
        let superview = NSView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        let view = NSView(frame: CGRect(x: 100, y: 100, width: 40, height: 20))
        view.wantsLayer = true
        superview.addSubview(view)
        return view
    }

    @Test func widthAndHeightResizeKeepingTheOrigin() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.width(30), .height(50), duration: 1)
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 0, y: 0, width: 20, height: 30))
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 0, y: 0, width: 30, height: 50))
    }

    @Test func frameAnimatesPositionAndSizeAndANewerXTakesOnlyThePosition() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let older = view.animate(.frame(CGRect(x: 100, y: 40, width: 30, height: 50)), duration: 1)
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 50, y: 20, width: 20, height: 30))
        view.animate(.x(0), duration: 0.5)
        frames.step(0.5)
        #expect(view.frame == CGRect(x: 0, y: 40, width: 30, height: 50))
        #expect(older.state == .finished)
    }

    @Test func aNegativeFrameIsStandardised() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.animate(.frame(CGRect(x: 40, y: 40, width: -20, height: -20)), duration: 1)
        frames.step(1)
        #expect(view.frame == CGRect(x: 20, y: 20, width: 20, height: 20))
    }

    @Test func rotationTurnsAboutTheCentre() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 90), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frameRotation, 45))
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
        frames.step(0.5)
        #expect(approx(view.frameRotation, 90))
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
        #expect(view.frame.size == CGSize(width: 40, height: 20))
        #expect(approx(view.x, 100) && approx(view.y, 100))
    }

    @Test func rotationIsUnwrapped() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 720), duration: 1)
        frames.step(1)
        #expect(view.rotation == 720)  // AppKit's own frameRotation wraps to about 0
        view.animate(.rotation(degrees: 630), duration: 1)
        frames.step(0.5)
        #expect(approx(view.rotation, 675))
        #expect(approx(view.frameRotation, -45))  // turned back, not forward through 0
        frames.step(0.5)
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
    }

    @Test func rotationReadsAnAngleSetOutsideKinieta() {
        let view = makeViewInSuperview()
        view.rotation = 400
        #expect(view.rotation == 400)
        view.frameCenterRotation = 30
        #expect(approx(view.rotation, 30))
    }

    @Test func positionAndSizeAnimateAlongsideARotation() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 90), .x(200), .width(60), duration: 1)
        frames.step(0.5)
        // Unrotated, the view would be at (150, 100), 50 by 20: centred on (175, 110).
        #expect(approx(centre(of: view), CGPoint(x: 175, y: 110)))
        #expect(approx(view.frameRotation, 45))
        frames.step(0.5)
        #expect(approx(centre(of: view), CGPoint(x: 230, y: 110)))
        #expect(approx(view.frameRotation, 90))
        #expect(approx(view.x, 200) && approx(view.y, 100))
        #expect(view.frame.size == CGSize(width: 60, height: 20))
    }

    @Test func reduceMotionSnapsSizeAndRotation() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        Engine.shared.isReduceMotionEnabled = { true }
        let view = makeViewInSuperview()
        view.animate(.width(60), .rotation(degrees: 90), duration: 1)
        frames.step(0.5)
        #expect(view.frame.width == 60)
        #expect(approx(view.rotation, 90))
    }

    // MARK: Colours

    /// The extended-sRGB components of a layer colour.
    private func components(of color: CGColor?) -> ColorMath.RGB? {
        color.flatMap(NSColor.init(cgColor:)).flatMap(ColorMath.extractComponents(of:))
    }

    private func same(_ a: ColorMath.RGB?, _ b: ColorMath.RGB?, tolerance: CGFloat = 1e-4) -> Bool {
        guard let a, let b else { return false }
        return [a.red - b.red, a.green - b.green, a.blue - b.blue, a.alpha - b.alpha].allSatisfy {
            abs($0) <= tolerance
        }
    }

    private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> ColorMath.RGB {
        ColorMath.RGB(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Black in the light appearances, white in the dark ones.
    private let blackOrWhite = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .white : .black
    }

    @Test func backgroundAndBorderColourAnimateTheLayer() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.layer?.backgroundColor = NSColor.red.cgColor
        view.animate(
            .background(.blue, interpolation: .rgb), .borderColor(.green, interpolation: .rgb), duration: 1)
        frames.step(0.5)
        #expect(same(components(of: view.layer?.backgroundColor), rgb(0.5, 0, 0.5)))
        // A layer's border colour starts out opaque black, as on UIKit.
        #expect(same(components(of: view.layer?.borderColor), rgb(0, 0.5, 0)))
        frames.step(0.5)
        #expect(same(components(of: view.layer?.backgroundColor), rgb(0, 0, 1)))
        #expect(same(components(of: view.layer?.borderColor), rgb(0, 1, 0)))
    }

    @Test func aViewWithoutALayerIsGivenOne() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(view.layer == nil)
        view.animate(.background(.red), duration: 1)
        frames.step(1)
        #expect(view.wantsLayer)
        #expect(same(components(of: view.layer?.backgroundColor), rgb(1, 0, 0)))
    }

    @Test func animatesTheLayersBorderWidthAndCornerRadius() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.layer?.borderWidth = 2
        view.animate(.borderWidth(6), .cornerRadius(8), duration: 1)
        frames.step(0.5)
        #expect(approx(view.layer?.borderWidth ?? -1, 4))
        #expect(approx(view.layer?.cornerRadius ?? -1, 4))
        frames.step(0.5)
        #expect(approx(view.layer?.borderWidth ?? -1, 6))
        #expect(approx(view.layer?.cornerRadius ?? -1, 8))
    }

    @Test func borderWidthAndCornerRadiusGiveAViewWithoutALayerOne() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(view.layer == nil)
        view.animate(.borderWidth(2), .cornerRadius(4), duration: 1)
        frames.step(0.5)
        #expect(view.wantsLayer)
        #expect(approx(view.layer?.borderWidth ?? -1, 1))
        #expect(approx(view.layer?.cornerRadius ?? -1, 2))
    }

    @Test func borderWidthAndCornerRadiusStayAtLeastZeroWhenTheEasingOvershoots() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.layer?.borderWidth = 2
        view.layer?.cornerRadius = 3
        view.animate(.borderWidth(0), .cornerRadius(0), duration: 1).easing(.inOut(.back))
        for _ in 0..<10 {
            frames.step(0.1)
            #expect((view.layer?.borderWidth ?? -1) >= 0 && (view.layer?.cornerRadius ?? -1) >= 0)
        }
    }

    @Test func borderWidthAndCornerRadiusStillAnimateUnderReduceMotion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        Engine.shared.isReduceMotionEnabled = { true }
        let view = makeView()
        view.animate(.x(100), .borderWidth(4), .cornerRadius(6), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.layer?.borderWidth ?? -1, 2))
        #expect(approx(view.layer?.cornerRadius ?? -1, 3))
    }

    @Test func coloursStillAnimateUnderReduceMotion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        Engine.shared.isReduceMotionEnabled = { true }
        let view = makeView()
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.animate(.x(100), .background(.white, interpolation: .rgb), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frame.origin.x, 100))
        #expect(same(components(of: view.layer?.backgroundColor), rgb(0.5, 0.5, 0.5)))
    }

    @Test func extractingConvertsOtherColourSpacesAndNotPatterns() {
        #expect(same(ColorMath.extractComponents(of: NSColor(white: 0.5, alpha: 0.25)), rgb(0.5, 0.5, 0.5, 0.25)))
        let cmyk = NSColor(deviceCyan: 0, magenta: 1, yellow: 1, black: 0, alpha: 1)
        let red = ColorMath.extractComponents(of: cmyk)
        #expect(red.map { $0.red > 0.8 && $0.green < 0.3 && $0.blue < 0.3 } == true, "\(String(describing: red))")
        let pattern = NSColor(patternImage: NSImage(size: CGSize(width: 2, height: 2)))
        #expect(ColorMath.extractComponents(of: pattern) == nil)
    }

    /// AppKit converts with the ICC profile's rounded matrices, like UIKit.
    @Test func displayP3MatchesAppKit() {
        let steps = (0...4).map { CGFloat($0) / 4 }
        for r in steps {
            for g in steps {
                for b in steps {
                    let p3 = rgb(r, g, b, 0.5)
                    let color = NSColor(displayP3Red: r, green: g, blue: b, alpha: 0.5)
                    let extended = ColorMath.extractComponents(of: color)
                    #expect(same(extended, p3.fromDisplayP3, tolerance: ColorMath.Gamut.tolerance), "\(p3)")
                }
            }
        }
    }

    /// The extended-sRGB background `mode` gives at `progress` from `from` to `to`.
    private func background(
        from: NSColor, to: NSColor, _ mode: ColorInterpolation, at progress: CGFloat
    ) -> ColorMath.RGB? {
        let view = makeView()
        view.layer?.backgroundColor = from.cgColor
        Property.background(to, interpolation: mode).transformation(for: view, defaultColorInterpolation: .lch)(
            view, progress)
        return components(of: view.layer?.backgroundColor)
    }

    @Test(arguments: [ColorInterpolation.rgb, .hsb, .lch])
    func displayP3ColoursStayWideOnTheWay(_ mode: ColorInterpolation) throws {
        let red = NSColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
        let green = NSColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1)
        let tolerance = ColorMath.Gamut.tolerance

        let mid = try #require(background(from: red, to: green, mode, at: 0.5))
        #expect(!mid.isInUnitRange(tolerance: tolerance), "the midpoint is clipped to sRGB: \(mid)")
        #expect(mid.displayP3.isInUnitRange(tolerance: tolerance), "the midpoint is outside Display P3: \(mid)")

        // Just before the end the colour is already the target, so the last frame does not pop.
        let nearEnd = background(from: red, to: green, mode, at: 0.999)
        #expect(
            same(nearEnd, ColorMath.extractComponents(of: green), tolerance: 0.01), "\(String(describing: nearEnd))")
    }

    @Test(arguments: [ColorInterpolation.rgb, .hsb, .lch])
    func sRGBColoursStayInSRGBOnTheWay(_ mode: ColorInterpolation) throws {
        let pink = NSColor(srgbRed: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
        let cyan = NSColor(srgbRed: 0.00, green: 0.80, blue: 0.90, alpha: 1.00)
        for progress in stride(from: CGFloat(0.1), to: 1, by: 0.1) {
            let color = try #require(background(from: pink, to: cyan, mode, at: progress))
            #expect(color.isInUnitRange(tolerance: 0), "\(progress): \(color)")
        }
    }

    @Test func dynamicColoursResolveAgainstTheViewsAppearance() {
        // A dark view in a light app: the colour is white for the view, black for the app.
        let view = makeView()
        view.appearance = NSAppearance(named: .darkAqua)
        view.layer?.backgroundColor = NSColor.white.cgColor
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
            let step = Property.background(blackOrWhite).transformation(for: view, defaultColorInterpolation: .lch)
            step(view, 0.5)
            #expect(same(components(of: view.layer?.backgroundColor), rgb(1, 1, 1)))
            step(view, 1)
            #expect(same(components(of: view.layer?.backgroundColor), rgb(1, 1, 1)))
        }
    }

    @Test func dynamicColoursFollowAnAppearanceChangeMidAnimation() throws {
        // From a grey the midpoint shows which variant is in use.
        let view = makeView()
        view.appearance = NSAppearance(named: .aqua)
        view.layer?.borderColor = NSColor.gray.cgColor
        let step = Property.borderColor(blackOrWhite, interpolation: .rgb).transformation(
            for: view, defaultColorInterpolation: .lch)
        step(view, 0.5)
        let light = try #require(components(of: view.layer?.borderColor))
        #expect(light.red < 0.3, "\(light)")

        view.appearance = NSAppearance(named: .darkAqua)
        step(view, 0.5)
        let dark = try #require(components(of: view.layer?.borderColor))
        #expect(dark.red > 0.7, "\(dark)")
        step(view, 1)
        #expect(same(components(of: view.layer?.borderColor), rgb(1, 1, 1)))

        view.appearance = NSAppearance(named: .aqua)
        step(view, 0.5)
        #expect(components(of: view.layer?.borderColor) == light)
    }

    @Test func nsColorAndCGColorAreInterpolatable() {
        let red = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        #expect(red.interpolated(to: blue, progress: 0) === red)
        #expect(red.interpolated(to: blue, progress: 1) === blue)
        let mid = ColorMath.extractComponents(of: red.interpolated(to: blue, progress: 0.5))
        #expect(
            same(mid, ColorMath.RGB(red: 1, green: 0, blue: 0, alpha: 1).lch.lerp(rgb(0, 0, 1).lch, 0.5).rgb.clamped()))
        let cgMid = red.cgColor.interpolated(to: blue.cgColor, progress: 0.5)
        #expect(same(components(of: cgMid), mid))
    }

    // MARK: Key paths and constraint constants

    @Test func aKeyPathReachesThroughTheLayer() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.layer?.shadowOffset = .zero
        view.animate(
            .custom(\.layer!.shadowOpacity, to: 0.8), .custom(\.layer!.shadowOffset, to: CGSize(width: 0, height: 8)),
            duration: 1)
        frames.step(0.25)
        #expect(approx(CGFloat(view.layer!.shadowOpacity), 0.2))
        #expect(view.layer?.shadowOffset == CGSize(width: 0, height: 2))
        #expect(!Property.custom(\.layer!.shadowOpacity, to: 1).isMotion)
    }

    @Test func aSubclassKeyPathAnimatesItsColourLikeTheBackground() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let pink = NSColor(srgbRed: 1.00, green: 0.44, blue: 0.75, alpha: 1)
        let cyan = NSColor(srgbRed: 0.00, green: 0.80, blue: 0.90, alpha: 1)
        let box = NSBox(), reference = makeView()
        box.fillColor = pink
        reference.layer?.backgroundColor = pink.cgColor
        box.animate(.custom(\NSBox.fillColor, to: cyan), duration: 1)
        reference.animate(.background(cyan), duration: 1)
        frames.step(0.5)
        #expect(
            same(ColorMath.extractComponents(of: box.fillColor), components(of: reference.layer?.backgroundColor)))
        frames.step(0.5)
        // The target is assigned as given.
        #expect(box.fillColor === cyan)
    }

    @Test func aMissingShadowColourFadesInFromClearThroughTheEngineInterpolation() {
        Engine.shared.colorInterpolation = .rgb
        defer { Engine.shared.colorInterpolation = .lch }
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        view.layer?.shadowColor = nil
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1).cgColor
        view.animate(.custom(\.layer!.shadowColor, to: blue), duration: 1)
        frames.step(0.5)
        #expect(same(components(of: view.layer?.shadowColor), rgb(0, 0, 1, 0.5), tolerance: 1e-3))
        frames.step(0.5)
        #expect(view.layer?.shadowColor === blue)
    }

    @Test func anInterpolationOverridesTheEngineForEachColourKeyPath() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let red = NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        let box = NSBox()
        box.fillColor = red
        box.wantsLayer = true
        box.layer?.shadowColor = red.cgColor
        box.animate(
            .custom(\NSBox.fillColor, to: blue, interpolation: .rgb),
            .custom(\.layer!.shadowColor, to: blue.cgColor, interpolation: .rgb), duration: 1)
        frames.step(0.5)
        // Straight through sRGB, where the engine's LCH would pass through neither.
        #expect(same(ColorMath.extractComponents(of: box.fillColor), rgb(0.5, 0, 0.5)))
        #expect(same(components(of: box.layer?.shadowColor), rgb(0.5, 0, 0.5)))
        frames.step(0.5)
        #expect(box.fillColor === blue)
    }

    @Test func aSubclassKeyPathOnAnotherViewDoesNothing() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.custom(\NSBox.fillColor, to: .red), .alpha(0), duration: 1)
            .onComplete { completed = true }
        frames.step(1)
        #expect(view.alphaValue == 0)
        #expect(completed && handle.state == .finished)
    }

    @Test func keyPathsToTheRotationShareItsKeyAndAreMotion() {
        let rotation = Property.rotation(degrees: 0).key
        #expect(Property.custom(\.frameRotation, to: 0).key == rotation)
        #expect(Property.custom(\.frameCenterRotation, to: 0).key == rotation)
        #expect(Property.custom(\NSBox.frameCenterRotation, to: 0).key == rotation)
        #expect(Property.custom(\.alphaValue, to: 0).key != rotation)
        #expect(Property.custom(\.frameCenterRotation, to: 0).isMotion)
        #expect(!Property.custom(\.frameCenterRotation, to: 0, isMotion: false).isMotion)
        #expect(!Property.custom(\.alphaValue, to: 0).isMotion)
        // In one animation the last of them wins.
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeViewInSuperview()
        view.animate(.rotation(degrees: 90), .custom(\.frameCenterRotation, to: 20), duration: 1)
        frames.step(0.5)
        #expect(approx(view.frameRotation, 10))
        #expect(approx(centre(of: view), CGPoint(x: 120, y: 110)))
    }

    @Test func aConstraintConstantAnimatesAndSurvivesTheNextLayoutPass() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let (container, child, leading) = constrainedChild()
        let handle = child.animate(.constant(of: leading, to: 110), duration: 1)
        frames.step(0.5)
        // Laid out on the frame itself, not on the next layout pass.
        #expect(child.frame.minX == 60)
        frames.step(0.5)
        #expect(handle.state == .finished)
        container.needsLayout = true
        container.layoutSubtreeIfNeeded()
        #expect(leading.constant == 110)
        #expect(child.frame.minX == 110)
        #expect(Property.constant(of: leading, to: 0).isMotion)
    }

    @Test func constraintConstantsLayOutTheNearestCommonSuperview() {
        let root = NSView(), parent = NSView(), a = NSView(), b = NSView()
        root.addSubview(parent)
        parent.addSubview(a)
        parent.addSubview(b)
        let guide = NSLayoutGuide()
        root.addLayoutGuide(guide)
        #expect(a.leadingAnchor.constraint(equalTo: b.trailingAnchor).layoutContainer === parent)
        #expect(a.topAnchor.constraint(equalTo: parent.topAnchor).layoutContainer === parent)
        #expect(a.leadingAnchor.constraint(equalTo: guide.leadingAnchor).layoutContainer === root)
        #expect(a.widthAnchor.constraint(equalToConstant: 10).layoutContainer === parent)
        // A view with no superview lays itself out.
        let lone = NSView()
        #expect(lone.widthAnchor.constraint(equalToConstant: 10).layoutContainer === lone)
    }

    @Test func aReleasedConstraintIsSkipped() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = makeView()
        let property: Kinieta.Property = autoreleasepool {
            .constant(of: view.widthAnchor.constraint(equalToConstant: 10), to: 20)
        }
        #expect(property.name.hasPrefix("constant("))
        let handle = view.animate(property, .alpha(0), duration: 1)
        frames.step(1)
        #expect(handle.state == .finished)
        #expect(view.alphaValue == 0)
    }

    /// A 20-point square inside a 200 by 100 container, 10 points from its leading edge.
    private func constrainedChild() -> (NSView, NSView, NSLayoutConstraint) {
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let child = NSView()
        child.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(child)
        let leading = child.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10)
        NSLayoutConstraint.activate([
            leading,
            child.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            child.widthAnchor.constraint(equalToConstant: 20),
            child.heightAnchor.constraint(equalToConstant: 20),
        ])
        container.layoutSubtreeIfNeeded()
        return (container, child, leading)
    }

    @Test(.timeLimit(.minutes(1)))
    func releasingTheViewCancelsItsTimelines() async {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        var view: NSView? = makeView()
        let paused = view!.animate(.x(100), duration: 1)
        frames.step()
        paused.pause()
        view = nil
        await paused.finished()
        #expect(paused.state == .cancelled && paused.view == nil)
    }

    /// Makes `driver` the source of frames for `Engine.shared` until the returned closure is called.
    private func install(_ driver: Engine.DisplayLinkDriver) -> () -> Void {
        let previous = Engine.shared.driver
        Engine.shared.driver = driver
        return { Engine.shared.driver = previous }
    }

    @Test(.timeLimit(.minutes(1)))
    func withoutAScreenATimerDrivesTheTimelineToCompletion() async {
        let driver = Engine.DisplayLinkDriver()
        driver.fallbackScreen = { nil }
        let uninstall = install(driver)
        defer { uninstall() }
        let view = makeView()
        var completed = false
        let handle = view.animate(.x(100), duration: 0.2).onComplete { completed = true }
        #expect(driver.isRunning && driver.timer != nil && driver.displayLink == nil)
        await handle.finished()
        #expect(handle.state == .finished && completed)
        #expect(approx(view.frame.origin.x, 100))
        #expect(!driver.isRunning && driver.timer == nil)
    }

    @Test func theTimerRunsAtThePreferredOrMaximumRateUpTo60Hz() throws {
        let driver = Engine.DisplayLinkDriver()
        driver.fallbackScreen = { nil }
        driver.start { _ in }
        defer { driver.stop() }
        #expect(approx(try #require(driver.timer).timeInterval, 1.0 / 60))
        driver.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
        #expect(approx(try #require(driver.timer).timeInterval, 1.0 / 30))
        driver.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 24, preferred: 0)
        #expect(approx(try #require(driver.timer).timeInterval, 1.0 / 24))
        driver.preferredFrameRateRange = .default
        #expect(approx(try #require(driver.timer).timeInterval, 1.0 / 60))
    }

    @Test func aScreenAppearingReplacesTheTimerWithADisplayLink() throws {
        let screen = try #require(NSScreen.screens.first, "AppKit hands out display links only for a screen")
        let driver = Engine.DisplayLinkDriver()
        var available: NSScreen?
        driver.fallbackScreen = { available }
        driver.start { _ in }
        defer { driver.stop() }
        #expect(driver.timer != nil && driver.displayLink == nil)

        available = screen
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        #expect(driver.timer == nil && driver.displayLink != nil)
        #expect(driver.displayID == screen.displayID)

        available = nil
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        #expect(driver.timer != nil && driver.displayLink == nil && driver.displayID == nil)

        driver.stop()
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        #expect(!driver.isRunning)
    }

    @Test func theLinkFollowsTheScreenOfTheLatestAnimatedViewsWindow() throws {
        let window = NSWindow(
            contentRect: CGRect(x: 100, y: 100, width: 50, height: 50), styleMask: .borderless,
            backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        let screen = try #require(window.screen, "the window needs a screen to follow")
        let driver = Engine.DisplayLinkDriver()
        driver.fallbackScreen = { nil }
        let uninstall = install(driver)
        defer { uninstall() }

        let outside = makeView()
        let first = outside.animate(.x(100), duration: 1)
        #expect(driver.timer != nil)  // a view outside a window has no screen

        let inside = makeView()
        window.contentView!.addSubview(inside)
        let handle = inside.animate(.x(100), duration: 1)
        #expect(driver.displayLink != nil && driver.timer == nil)
        #expect(driver.displayID == screen.displayID)

        // A later animation of a view without a screen takes the driver back to the fallback.
        let last = outside.animate(.alpha(0), duration: 1)
        #expect(driver.timer != nil && driver.displayID == nil)

        // The followed view's window reports a screen change.
        window.contentView!.addSubview(outside)
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        #expect(driver.displayLink != nil && driver.displayID == screen.displayID)

        for running in [first, handle, last] { running.cancel() }
        #expect(!driver.isRunning)
    }

    @Test(.timeLimit(.minutes(1)))
    func realDisplayLinkRunsATimelineToCompletion() async {
        #expect(Engine.shared.driver is Engine.DisplayLinkDriver)  // or its timer, on a Mac without a screen
        let view = makeView()
        let handle = view.animate(.x(100), .alpha(0), duration: 0.2)
        await handle.finished()
        #expect(handle.state == .finished)
        #expect(approx(view.frame.origin.x, 100))
        #expect(approx(view.alphaValue, 0))
    }
}
#endif
