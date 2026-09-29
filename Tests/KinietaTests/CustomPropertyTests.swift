#if canImport(UIKit)
import Testing
import UIKit

@testable import Kinieta

/// `Interpolatable`, `.custom` key paths and `.constant` constraint constants,
/// driven through the public API with a `ManualFrameDriver`.
@Suite(.serialized, .usesSharedEngine)
@MainActor
struct CustomPropertyTests {

    init() {
        Engine.shared.isReduceMotionEnabled = { false }
    }

    // MARK: Interpolatable

    @Test func numbersAndGeometryLandExactlyOnTheirEndpoints() {
        let from = CGRect(x: 0.1, y: 0.7, width: 3.3, height: 0.3)
        let to = CGRect(x: 1.9, y: -0.2, width: 0.7, height: 5.1)
        #expect(from.interpolated(to: to, progress: 0) == from)
        #expect(from.interpolated(to: to, progress: 1) == to)
        #expect(CGFloat(0.1).interpolated(to: 0.7, progress: 1) == 0.7)
        #expect(Double(0.1).interpolated(to: 0.7, progress: 1) == 0.7)
        #expect(Float(0.1).interpolated(to: 0.7, progress: 1) == 0.7)
    }

    @Test func geometryInterpolatesEachComponentAndExtrapolatesAnOvershoot() {
        #expect(CGPoint(x: 0, y: 10).interpolated(to: CGPoint(x: 100, y: 30), progress: 0.25) == CGPoint(x: 25, y: 15))
        #expect(
            CGSize(width: 10, height: 0).interpolated(to: CGSize(width: 20, height: 40), progress: 1.5)
                == CGSize(width: 25, height: 60))
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
            .interpolated(to: CGRect(x: 100, y: 50, width: -10, height: 30), progress: 0.5)
        // Neither end is standardised, so the width passes through zero.
        #expect(rect.origin == CGPoint(x: 50, y: 25))
        #expect(rect.size == CGSize(width: 0, height: 20))
        #expect(Float(1).interpolated(to: 3, progress: -0.5) == 0)
    }

    @Test func coloursInterpolateThroughLCHAndKeepTheirEndpoints() throws {
        let pink = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1)
        let cyan = UIColor(red: 0.00, green: 0.80, blue: 0.90, alpha: 1)
        #expect(pink.interpolated(to: cyan, progress: 0) === pink)
        #expect(pink.interpolated(to: cyan, progress: 1) === cyan)
        #expect(pink.interpolated(to: cyan, progress: 1.4) === cyan)

        let lch = try #require(ColorMath.interpolator(from: pink, to: cyan, mode: .lch, traits: nil))
        let mid = pink.interpolated(to: cyan, progress: 0.5)
        #expect(ColorMath.extractComponents(of: mid) == ColorMath.extractComponents(of: lch(0.5)))
    }

    // MARK: Transforms

    @Test func aTransformRotatesWithoutShrinking() {
        let quarter = CGAffineTransform(rotationAngle: .pi / 2)
        let mid = CGAffineTransform.identity.interpolated(to: quarter, progress: 0.5)
        // Entry by entry it would be scaled by cos 45°, about 0.71.
        #expect(approx(mid, CGAffineTransform(rotationAngle: .pi / 4)))
        #expect(approx(mid.a * mid.d - mid.b * mid.c, 1))
    }

    @Test func aTransformTurnsTheShorterWayRound() {
        let from = CGAffineTransform(rotationAngle: 170 * .pi / 180)
        let to = CGAffineTransform(rotationAngle: -170 * .pi / 180)
        #expect(approx(from.interpolated(to: to, progress: 0.5), CGAffineTransform(rotationAngle: .pi)))
        #expect(
            approx(to.interpolated(to: from, progress: 0.25), CGAffineTransform(rotationAngle: -175 * .pi / 180)))
    }

    @Test func aTransformInterpolatesEachPartAndKeepsItsEnds() {
        func transform(scale: CGFloat, degrees: CGFloat, x: CGFloat) -> CGAffineTransform {
            CGAffineTransform(scaleX: scale, y: scale * 2)
                .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
                .concatenating(CGAffineTransform(translationX: x, y: -x))
        }
        let from = transform(scale: 1, degrees: 10, x: 0), to = transform(scale: 3, degrees: 70, x: 100)
        #expect(approx(from.interpolated(to: to, progress: 0.5), transform(scale: 2, degrees: 40, x: 50)))
        // An overshoot extrapolates every part.
        #expect(approx(from.interpolated(to: to, progress: 1.5), transform(scale: 4, degrees: 100, x: 150)))
        #expect(from.interpolated(to: to, progress: 0) == from)
        #expect(from.interpolated(to: to, progress: 1) == to)
    }

    @Test func anyTransformSurvivesItsDecomposition() {
        let transforms = [
            CGAffineTransform(a: 1, b: 0.5, c: 0.25, d: 1, tx: 3, ty: 4),
            CGAffineTransform(a: -2, b: 1, c: 0.5, d: 3, tx: 0, ty: -7),
            CGAffineTransform(a: 0.3, b: -1.2, c: 2, d: 0.1, tx: 1, ty: 1),
            CGAffineTransform(a: 0, b: 0, c: 1, d: 2, tx: 5, ty: 0),
            CGAffineTransform(a: 0, b: 0, c: 0, d: 0, tx: 5, ty: 6),
            CGAffineTransform(scaleX: -1, y: -1),
        ]
        for t in transforms {
            #expect(approx(t.interpolated(to: t, progress: 0.5), t), "\(t)")
        }
    }

    @Test func aFlipScalesThroughZeroInsteadOfTurning() {
        let flipX = CGAffineTransform(scaleX: -1, y: 1), flipY = CGAffineTransform(scaleX: 1, y: -1)
        #expect(
            approx(
                CGAffineTransform.identity.interpolated(to: flipX, progress: 0.5), CGAffineTransform(scaleX: 0, y: 1)))
        #expect(
            approx(
                CGAffineTransform.identity.interpolated(to: flipY, progress: 0.5), CGAffineTransform(scaleX: 1, y: 0)))
        // A flip in x is a flip in y and half a turn: going from one to the other turns, not squashes.
        let mid = flipX.interpolated(to: flipY, progress: 0.5)
        #expect(
            approx(mid, CGAffineTransform(scaleX: 1, y: -1).concatenating(CGAffineTransform(rotationAngle: .pi / 2))))
    }

    @Test func aTransformGrowingFromNothingDoesNotSpin() {
        let target = CGAffineTransform(rotationAngle: .pi / 2)
        let mid = CGAffineTransform(scaleX: 0, y: 0).interpolated(to: target, progress: 0.5)
        #expect(
            approx(mid, CGAffineTransform(scaleX: 0.5, y: 0.5).concatenating(CGAffineTransform(rotationAngle: .pi / 2)))
        )
    }

    @Test func aViewTransformAnimatesThroughItsKeyPathAndIsMotion() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView(frame: CGRect(x: 10, y: 20, width: 100, height: 50))
        let target = CGAffineTransform(scaleX: 3, y: 3).rotated(by: .pi / 2)
        view.animate(.custom(\.transform, to: target), duration: 1)
        frames.step(0.5)
        #expect(approx(view.transform, CGAffineTransform(scaleX: 2, y: 2).rotated(by: .pi / 4)))
        // The transform leaves the untransformed geometry alone.
        #expect(view.center == CGPoint(x: 60, y: 45))
        #expect(view.bounds.size == CGSize(width: 100, height: 50))
        frames.step(0.5)
        #expect(view.transform == target)
        #expect(Property.custom(\.transform, to: .identity).isMotion)
        #expect(!Property.custom(\.transform, to: .identity, isMotion: false).isMotion)
    }

    @Test func everyKeyPathToTheViewTransformSharesTheRotationKey() {
        let rotation = Property.rotation(degrees: 0).key
        #expect(Property.custom(\.transform, to: .identity).key == rotation)
        #expect(Property.custom(\UIView.transform, to: .identity).key == rotation)
        #expect(Property.custom(\UIImageView.transform, to: .identity).key == rotation)
        #expect(Property.custom(\TransformView.extra, to: .identity).key != rotation)
        #expect(Property.custom(\.layer.shadowOpacity, to: 1).key != rotation)
        // In one animation the last of them wins.
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        view.animate(.rotation(degrees: 90), .custom(\.transform, to: .identity), duration: 1)
        frames.step(0.5)
        #expect(view.transform == .identity)
    }

    // MARK: CGColor

    @Test func aCGColorInterpolatesLikeItsUIColor() throws {
        let pink = CGColor(srgbRed: 1, green: 0.44, blue: 0.75, alpha: 1)
        let cyan = CGColor(srgbRed: 0, green: 0.8, blue: 0.9, alpha: 1)
        #expect(pink.interpolated(to: cyan, progress: 0) === pink)
        #expect(pink.interpolated(to: cyan, progress: 1) === cyan)
        #expect(pink.interpolated(to: cyan, progress: -0.4) === pink)
        let mid = UIColor(cgColor: pink.interpolated(to: cyan, progress: 0.5))
        let reference = UIColor(cgColor: pink).interpolated(to: UIColor(cgColor: cyan), progress: 0.5)
        #expect(ColorMath.extractComponents(of: mid) == ColorMath.extractComponents(of: reference))
    }

    @Test func aShadowColourAnimatesThroughTheEngineInterpolation() throws {
        Engine.shared.colorInterpolation = .rgb
        defer { Engine.shared.colorInterpolation = .lch }
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        view.layer.shadowColor = UIColor.red.cgColor
        let blue = UIColor.blue.cgColor
        view.animate(.custom(\.layer.shadowColor, to: blue), duration: 1)
        frames.step(0.5)
        let mid = try #require(view.layer.shadowColor.flatMap { ColorMath.extractComponents(of: UIColor(cgColor: $0)) })
        #expect(approx(mid.red, 0.5) && approx(mid.green, 0) && approx(mid.blue, 0.5))
        frames.step(0.5)
        #expect(view.layer.shadowColor === blue)
        #expect(!Property.custom(\.layer.shadowColor, to: blue).isMotion)
    }

    @Test func aMissingCGColorFadesInFromClear() throws {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        view.layer.shadowColor = nil
        view.animate(.custom(\.layer.shadowColor, to: UIColor.blue.cgColor), duration: 1)
        frames.step(0.5)
        let mid = try #require(view.layer.shadowColor.flatMap { ColorMath.extractComponents(of: UIColor(cgColor: $0)) })
        #expect(approx(mid.alpha, 0.5, 1e-3))
        #expect(approx(mid.blue, 1, 1e-3) && approx(mid.red, 0, 1e-3))
    }

    @Test func aTypeOfYourOwnAnimatesThroughAKeyPath() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = VectorView()
        view.animate(.custom(\VectorView.vector, to: Vector(dx: 10, dy: -20)), duration: 1)
        frames.step(0.5)
        #expect(view.vector == Vector(dx: 5, dy: -10))
        frames.step(0.5)
        #expect(view.vector == Vector(dx: 10, dy: -20))
    }

    // MARK: Key paths

    @Test func aKeyPathAnimatesLikeTheMatchingCase() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let custom = UIView(), builtIn = UIView()
        custom.animate(.custom(\.alpha, to: 0), duration: 1).easeInOut(.cubic)
        builtIn.animate(.alpha(0), duration: 1).easeInOut(.cubic)
        for _ in 0..<4 {
            frames.step(0.25)
            #expect(custom.alpha == builtIn.alpha)
        }
        #expect(custom.alpha == 0)
    }

    @Test func aKeyPathReachesThroughTheLayer() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        view.animate(
            .custom(\.layer.shadowOpacity, to: 0.8), .custom(\.layer.shadowOffset, to: CGSize(width: 0, height: 8)),
            duration: 1)
        frames.step(0.25)
        #expect(approx(view.layer.shadowOpacity, 0.2))
        // From the default offset, (0, -3).
        #expect(view.layer.shadowOffset == CGSize(width: 0, height: -0.25))
    }

    @Test func aSubclassKeyPathAnimatesItsColourLikeTheBackground() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let label = UILabel(), reference = UIView()
        label.textColor = .systemPink
        reference.backgroundColor = .systemPink
        label.animate(.custom(\UILabel.textColor, to: .systemTeal), duration: 1)
        reference.animate(.background(.systemTeal), duration: 1)
        frames.step(0.5)
        #expect(
            ColorMath.extractComponents(of: label.textColor)
                == ColorMath.extractComponents(of: reference.backgroundColor!))
        frames.step(0.5)
        // The target is assigned as given, so it keeps adapting to Dark Mode.
        #expect(label.textColor === UIColor.systemTeal)
    }

    @Test func colourKeyPathsFollowTheEngineInterpolation() throws {
        Engine.shared.colorInterpolation = .rgb
        defer { Engine.shared.colorInterpolation = .lch }
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = ColorView()
        view.color = .red
        view.animate(.custom(\ColorView.color, to: .blue), duration: 1)
        frames.step(0.5)
        let mid = try #require(view.color.flatMap(ColorMath.extractComponents(of:)))
        #expect(approx(mid.red, 0.5) && approx(mid.green, 0) && approx(mid.blue, 0.5))
    }

    @Test func anImplicitlyUnwrappedColourAnimates() throws {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let button = UIButton()
        button.tintColor = .red
        button.animate(.custom(\.tintColor, to: .blue), duration: 1)
        frames.step(0.5)
        let mid = try #require(ColorMath.extractComponents(of: button.tintColor))
        #expect(mid.red > 0 && mid.blue > 0)
        frames.step(0.5)
        #expect(button.tintColor == .blue)
    }

    @Test func aSubclassKeyPathOnAnotherViewDoesNothing() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        var completed = false
        let handle = view.animate(.custom(\UILabel.textColor, to: .red), .alpha(0), duration: 1)
            .onComplete { completed = true }
        frames.step(1)
        #expect(view.alpha == 0)
        #expect(completed)
        #expect(handle.state == .finished)
    }

    @Test func aMissingColourFadesInFromClear() throws {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = ColorView()
        view.animate(.custom(\ColorView.color, to: UIColor(red: 0, green: 0, blue: 1, alpha: 1)), duration: 1)
        frames.step(0.5)
        let mid = try #require(view.color.flatMap(ColorMath.extractComponents(of:)))
        #expect(approx(mid.alpha, 0.5, 1e-3))
        #expect(approx(mid.blue, 1, 1e-3) && approx(mid.red, 0, 1e-3))
    }

    @Test func aMissingValueSwitchesOnTheFirstFrame() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = VectorView()
        view.optionalOffset = nil
        view.animate(.custom(\VectorView.optionalOffset, to: 40), duration: 1)
        frames.step(0.1)
        #expect(view.optionalOffset == 40)
        view.animate(.custom(\VectorView.optionalOffset, to: 0), duration: 1)
        frames.step(0.25)
        #expect(view.optionalOffset == 30)
    }

    @Test func theLastValueForAKeyPathWins() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        view.animate(.custom(\.alpha, to: 0), .custom(\.alpha, to: 0.5), duration: 1)
        frames.step(0.5)
        #expect(approx(view.alpha, 0.75))
        frames.step(0.5)
        #expect(view.alpha == 0.5)
    }

    // MARK: Constraint constants

    @Test func aConstraintConstantAnimatesAndSurvivesTheNextLayoutPass() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let (container, child, leading) = constrainedChild()
        let handle = child.animate(.constant(leading, to: 110), duration: 1)
        frames.step(0.5)
        // Laid out on the frame itself, not on the next layout pass.
        #expect(child.frame.minX == 60)
        frames.step(0.5)
        #expect(handle.state == .finished)
        container.setNeedsLayout()
        container.layoutIfNeeded()
        #expect(leading.constant == 110)
        #expect(child.frame.minX == 110)
    }

    @Test func settingTheFrameOfAConstrainedViewSnapsBack() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let (container, child, _) = constrainedChild()
        child.animate(.x(110), duration: 1)
        frames.step(1)
        #expect(child.frame.minX == 110)
        container.setNeedsLayout()
        container.layoutIfNeeded()
        #expect(child.frame.minX == 10)
    }

    @Test func constraintConstantsLayOutTheNearestCommonSuperview() {
        let root = UIView(), parent = UIView(), a = UIView(), b = UIView()
        root.addSubview(parent)
        parent.addSubview(a)
        parent.addSubview(b)
        let guide = UILayoutGuide()
        root.addLayoutGuide(guide)
        #expect(a.leadingAnchor.constraint(equalTo: b.trailingAnchor).layoutContainer === parent)
        #expect(a.topAnchor.constraint(equalTo: parent.topAnchor).layoutContainer === parent)
        #expect(a.leadingAnchor.constraint(equalTo: guide.leadingAnchor).layoutContainer === root)
        #expect(a.widthAnchor.constraint(equalToConstant: 10).layoutContainer === parent)
        #expect(a.widthAnchor.constraint(equalTo: a.heightAnchor).layoutContainer === parent)
        // A view with no superview lays itself out.
        let lone = UIView()
        #expect(lone.widthAnchor.constraint(equalToConstant: 10).layoutContainer === lone)
    }

    @Test func aReleasedConstraintIsSkipped() {
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        let view = UIView()
        let property: Property = autoreleasepool {
            .constant(view.widthAnchor.constraint(equalToConstant: 10), to: 20)
        }
        let handle = view.animate(property, .alpha(0), duration: 1)
        frames.step(1)
        #expect(handle.state == .finished)
        #expect(view.alpha == 0)
    }

    // MARK: Reduce Motion

    @Test func underReduceMotionConstantsAndMotionKeyPathsSnapAndOtherKeyPathsAnimate() {
        Engine.shared.isReduceMotionEnabled = { true }
        defer { Engine.shared.isReduceMotionEnabled = { false } }
        let frames = ManualFrameDriver.install()
        defer { frames.uninstall() }
        // Keep the container: a constraint does not retain its items.
        let (container, child, leading) = constrainedChild()
        defer { withExtendedLifetime(container) {} }
        child.animate(
            .constant(leading, to: 110), .custom(\.alpha, to: 0),
            .custom(\.layer.shadowOffset, to: CGSize(width: 10, height: 10), isMotion: true), duration: 1)
        frames.step(0.5)
        #expect(leading.constant == 110)
        #expect(child.layer.shadowOffset == CGSize(width: 10, height: 10))
        #expect(approx(child.alpha, 0.5))
        #expect(Property.constant(leading, to: 0).isMotion)
        #expect(!Property.custom(\.alpha, to: 0).isMotion)
    }

    // MARK: Helpers

    /// A 20-point square inside a 200 by 100 container, 10 points from its leading edge.
    private func constrainedChild() -> (UIView, UIView, NSLayoutConstraint) {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let child = UIView()
        child.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(child)
        let leading = child.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10)
        NSLayoutConstraint.activate([
            leading,
            child.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            child.widthAnchor.constraint(equalToConstant: 20),
            child.heightAnchor.constraint(equalToConstant: 20),
        ])
        container.layoutIfNeeded()
        return (container, child, leading)
    }
}

/// Every entry within 1e-9.
private func approx(_ a: CGAffineTransform, _ b: CGAffineTransform) -> Bool {
    [a.a - b.a, a.b - b.b, a.c - b.c, a.d - b.d, a.tx - b.tx, a.ty - b.ty].allSatisfy { abs($0) < 1e-9 }
}

/// A value type Kinieta knows nothing about.
private struct Vector: Interpolatable, Equatable {
    var dx: CGFloat
    var dy: CGFloat

    func interpolated(to target: Vector, progress: CGFloat) -> Vector {
        Vector(
            dx: dx.interpolated(to: target.dx, progress: progress),
            dy: dy.interpolated(to: target.dy, progress: progress))
    }
}

private final class TransformView: UIView {
    var extra = CGAffineTransform.identity
}

private final class VectorView: UIView {
    var vector = Vector(dx: 0, dy: 0)
    var optionalOffset: CGFloat?
}

private final class ColorView: UIView {
    var color: UIColor?
}
#endif
