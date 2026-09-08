import Kinieta
import UIKit

/// A gallery of what Kinieta does: every easing preset on its own track, the
/// three colour interpolation modes side by side, and a composed timeline.
final class DemoViewController: UIViewController {

    private let stack = UIStackView()
    private var easingTracks: [(easing: Easing, square: UIView, track: UIView)] = []
    private var colourSwatches: [(mode: ColorInterpolation, view: UIView)] = []
    private var timelineSquares: [UIView] = []
    private let timelineStatus = UILabel()
    private var running: [Kinieta] = []

    private let pink = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
    private let cyan = UIColor(red: 0.00, green: 0.80, blue: 0.90, alpha: 1.00)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kinieta"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Play", style: .done, target: self, action: #selector(playAll))
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Reset", style: .plain, target: self, action: #selector(reset))
        buildLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // `-autoplay` starts the gallery on launch, for screenshots and recordings.
        if ProcessInfo.processInfo.arguments.contains("-autoplay") { playAll() }
    }

    // MARK: Layout

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40),
        ])

        addHeader("Easing", detail: "Each square crosses its track in 1.2 s with a different curve.")
        let presets: [(String, Easing)] = [
            ("linear", .linear),
            ("inOut(.sine)", .inOut(.sine)),
            ("inOut(.quad)", .inOut(.quad)),
            ("inOut(.cubic)", .inOut(.cubic)),
            ("inOut(.quart)", .inOut(.quart)),
            ("inOut(.quint)", .inOut(.quint)),
            ("inOut(.expo)", .inOut(.expo)),
            ("inOut(.back)", .inOut(.back)),
            ("custom(0.16, 0.73, 0.89, 0.24)", .custom(Bezier(0.16, 0.73, 0.89, 0.24))),
        ]
        for (name, easing) in presets {
            let (track, square) = makeTrack(label: name)
            easingTracks.append((easing, square, track))
        }

        addHeader("Colour", detail: "Pink to cyan through three colour spaces. LCH is the default.")
        for (name, mode) in [("rgb", ColorInterpolation.rgb), ("hsb", .hsb), ("lch", .lch)] {
            let swatch = UIView()
            swatch.backgroundColor = pink
            swatch.layer.cornerRadius = 8
            swatch.heightAnchor.constraint(equalToConstant: 36).isActive = true
            stack.addArrangedSubview(labelled(name, swatch))
            colourSwatches.append((mode, swatch))
        }

        addHeader(
            "Timeline", detail: "The first square moves, then the other two move together, then one completion fires.")
        let row = UIView()
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true
        for i in 0..<3 {
            let square = makeSquare(color: [pink, cyan, .systemIndigo][i])
            square.frame = CGRect(x: 6 + CGFloat(i) * 44, y: 6, width: 32, height: 32)
            row.addSubview(square)
            timelineSquares.append(square)
        }
        stack.addArrangedSubview(row)
        timelineStatus.font = .preferredFont(forTextStyle: .footnote)
        timelineStatus.textColor = .secondaryLabel
        timelineStatus.text = "Idle"
        stack.addArrangedSubview(timelineStatus)
    }

    private func addHeader(_ title: String, detail: String) {
        let heading = UILabel()
        heading.text = title
        heading.font = .preferredFont(forTextStyle: .title2)
        let sub = UILabel()
        sub.text = detail
        sub.numberOfLines = 0
        sub.font = .preferredFont(forTextStyle: .footnote)
        sub.textColor = .secondaryLabel
        let group = UIStackView(arrangedSubviews: [heading, sub])
        group.axis = .vertical
        group.spacing = 2
        stack.setCustomSpacing(24, after: stack.arrangedSubviews.last ?? UIView())
        stack.addArrangedSubview(group)
    }

    private func labelled(_ text: String, _ content: UIView) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        let group = UIStackView(arrangedSubviews: [label, content])
        group.axis = .vertical
        group.spacing = 4
        return group
    }

    private func makeTrack(label: String) -> (UIView, UIView) {
        let track = UIView()
        track.backgroundColor = .secondarySystemFill
        track.layer.cornerRadius = 8
        track.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let square = makeSquare(color: pink)
        square.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        track.addSubview(square)
        stack.addArrangedSubview(labelled(label, track))
        return (track, square)
    }

    private func makeSquare(color: UIColor) -> UIView {
        let square = UIView()
        square.backgroundColor = color
        square.layer.cornerRadius = 6
        return square
    }

    // MARK: Actions

    @objc private func playAll() {
        reset()
        view.layoutIfNeeded()
        for entry in easingTracks {
            let end = entry.track.bounds.width - 38
            let handle = entry.square
                .animate(.x(end), .rotation(degrees: 180), .cornerRadius(16), duration: 1.2).easing(entry.easing)
                .wait(0.4)
                .animate(.x(6), .rotation(degrees: 0), .cornerRadius(6), duration: 1.2).easing(entry.easing)
            running.append(handle)
        }
        for swatch in colourSwatches {
            let handle = swatch.view
                .animate(.background(cyan, interpolation: swatch.mode), duration: 1.6)
                .wait(0.4)
                .animate(.background(pink, interpolation: swatch.mode), duration: 1.6)
            running.append(handle)
        }
        let width = view.bounds.width - 40
        let first = timelineSquares[0].animate(.x(width - 38), duration: 1.0).easeInOut(.cubic)
        let second = timelineSquares[1]
            .wait(1.0)
            .animate(.x(width - 82), .alpha(0.3), duration: 0.8).easeOut(.back)
        let third = timelineSquares[2]
            .wait(1.0)
            .animate(.x(width - 126), .alpha(0.3), duration: 0.8).easeOut(.back)
        timelineStatus.text = "Running…"
        let group = Kinieta.group(first, second, third) { [weak self] in
            self?.timelineStatus.text = "Done: three timelines, one completion"
        }
        running.append(group)
    }

    @objc private func reset() {
        for handle in running { handle.cancel() }
        running.removeAll()
        for entry in easingTracks {
            entry.square.transform = .identity
            entry.square.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
            entry.square.layer.cornerRadius = 6
        }
        for swatch in colourSwatches { swatch.view.backgroundColor = pink }
        for (i, square) in timelineSquares.enumerated() {
            square.frame = CGRect(x: 6 + CGFloat(i) * 44, y: 6, width: 32, height: 32)
            square.alpha = 1
        }
        timelineStatus.text = "Idle"
    }
}
