import Kinieta
import UIKit

/// A gallery of what Kinieta does: every easing preset on its own track, the
/// three colour interpolation modes side by side, a composed timeline, one
/// handle driven by Pause, Resume and Cancel buttons, a square whose movement
/// newer animations take over mid-flight, and a view placed by Auto Layout
/// that animates its constraint.
final class DemoViewController: UIViewController {

    private let stack = UIStackView()
    private var easingTracks: [(easing: Easing, square: UIView, track: UIView)] = []
    private var colourSwatches: [(mode: ColorInterpolation, view: UIView)] = []
    private let darkSwatch = UIView()
    private let wideSwatch = UIView()
    private let timelineRow = UIView()
    private var timelineSquares: [UIView] = []
    private let timelineStatus = UILabel()
    private let reduceMotionStatus = UILabel()
    private let reduceMotionPicker = UISegmentedControl(items: ["Snap motion", "Snap all"])
    private var running: [Kinieta] = []
    private let controlsTrack = UIView()
    private let controlsSquare = UIView()
    private let controlsStatus = UILabel()
    private var controlsHandle: Kinieta?
    /// Whether the latest run of the Controls row was started by Loop.
    private var controlsLooping = false
    private let interruptTrack = UIView()
    private let interruptSquare = UIView()
    private let interruptStatus = UILabel()
    private var interruptHandles: [Kinieta] = []
    private let autoLayoutTrack = UIView()
    private let autoLayoutSquare = UIView()
    private var autoLayoutCentre: NSLayoutConstraint!
    private var autoLayoutHandle: Kinieta?
    /// One row of buttons that start the Controls row, and one that controls it:
    /// five do not fit across a phone.
    private lazy var controlButtons: [[(title: String, action: Selector)]] = [
        [("Play", #selector(playControls)), ("Loop", #selector(loopControls))],
        [
            ("Pause", #selector(pauseControls)), ("Resume", #selector(resumeControls)),
            ("Cancel", #selector(cancelControls)),
        ],
    ]
    private var controlButtonViews: [String: UIButton] = [:]
    private lazy var frameRateButton = UIBarButtonItem(
        title: nil, style: .plain, target: self, action: #selector(toggleFrameRate))

    private let pink = UIColor(red: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
    private let cyan = UIColor(red: 0.00, green: 0.80, blue: 0.90, alpha: 1.00)
    private let p3Red = UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
    private let p3Green = UIColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kinieta"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Play", style: .done, target: self, action: #selector(playAll)),
            frameRateButton,
        ]
        updateFrameRateButton()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Reset", style: .plain, target: self, action: #selector(reset))
        buildLayout()
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateReduceMotionStatus),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        updateReduceMotionStatus()
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
            // The safe area keeps the tracks clear of the sensor housing in landscape.
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
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
        // A dark panel in a light app: `.label` is white here, so the swatch should
        // brighten all the way instead of darkening and then snapping to white.
        let panel = UIView()
        panel.overrideUserInterfaceStyle = .dark
        panel.backgroundColor = .systemBackground
        panel.layer.cornerRadius = 8
        panel.heightAnchor.constraint(equalToConstant: 48).isActive = true
        darkSwatch.backgroundColor = pink
        darkSwatch.layer.cornerRadius = 6
        darkSwatch.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(darkSwatch)
        NSLayoutConstraint.activate([
            darkSwatch.topAnchor.constraint(equalTo: panel.topAnchor, constant: 6),
            darkSwatch.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 6),
            darkSwatch.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -6),
            darkSwatch.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -6),
        ])
        stack.addArrangedSubview(labelled("lch to .label, dark override", panel))
        // Both ends are outside sRGB. On a wide-colour display the frames in between
        // stay as saturated, so there is no jump on the last frame.
        wideSwatch.backgroundColor = p3Red
        wideSwatch.layer.cornerRadius = 8
        wideSwatch.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(labelled("lch, Display P3 red to green", wideSwatch))

        addHeader(
            "Timeline", detail: "The first square moves, then the other two move together, then one completion fires.")
        timelineRow.heightAnchor.constraint(equalToConstant: 44).isActive = true
        for i in 0..<3 {
            let square = makeSquare(color: [pink, cyan, .systemIndigo][i])
            square.frame = CGRect(x: 6 + CGFloat(i) * 44, y: 6, width: 32, height: 32)
            timelineRow.addSubview(square)
            timelineSquares.append(square)
        }
        stack.addArrangedSubview(timelineRow)
        timelineStatus.font = .preferredFont(forTextStyle: .footnote)
        timelineStatus.textColor = .secondaryLabel
        timelineStatus.text = "Idle"
        stack.addArrangedSubview(timelineStatus)

        addHeader(
            "Controls",
            detail: "One handle: round the corners, then() move out while a delayed spin and colour change run in "
                + "parallel(), come back after a delay, repeat twice, or with Loop repeatForever() until Cancel. "
                + "The label is set when await finished() returns.")
        controlsTrack.backgroundColor = .secondarySystemFill
        controlsTrack.layer.cornerRadius = 8
        controlsTrack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        controlsSquare.backgroundColor = pink
        controlsSquare.layer.cornerRadius = 6
        controlsSquare.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        controlsTrack.addSubview(controlsSquare)
        stack.addArrangedSubview(controlsTrack)
        for row in controlButtons {
            let buttons = UIStackView()
            buttons.distribution = .fillEqually
            buttons.spacing = 8
            for (title, action) in row {
                let button = UIButton(configuration: .gray())
                button.configuration?.title = title
                button.addTarget(self, action: action, for: .touchUpInside)
                buttons.addArrangedSubview(button)
                controlButtonViews[title] = button
            }
            stack.addArrangedSubview(buttons)
        }
        controlsStatus.font = .preferredFont(forTextStyle: .footnote)
        controlsStatus.textColor = .secondaryLabel
        controlsStatus.numberOfLines = 0
        controlsStatus.text = "Idle"
        stack.addArrangedSubview(controlsStatus)
        updateControlButtons()

        addHeader(
            "Interrupting",
            detail: "Play starts a 3 s move with a colour change. Tap Left or Right while it runs: "
                + "the new animation takes x over from where the square is, and the colour keeps going.")
        interruptTrack.backgroundColor = .secondarySystemFill
        interruptTrack.layer.cornerRadius = 8
        interruptTrack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        interruptSquare.backgroundColor = pink
        interruptSquare.layer.cornerRadius = 6
        interruptSquare.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        interruptTrack.addSubview(interruptSquare)
        stack.addArrangedSubview(interruptTrack)
        let directions = UIStackView()
        directions.distribution = .fillEqually
        directions.spacing = 8
        for (title, action) in [("Left", #selector(moveLeft)), ("Right", #selector(moveRight))] {
            let button = UIButton(configuration: .gray())
            button.configuration?.title = title
            button.addTarget(self, action: action, for: .touchUpInside)
            directions.addArrangedSubview(button)
        }
        stack.addArrangedSubview(directions)
        interruptStatus.font = .preferredFont(forTextStyle: .footnote)
        interruptStatus.textColor = .secondaryLabel
        interruptStatus.numberOfLines = 0
        interruptStatus.text = "Idle"
        stack.addArrangedSubview(interruptStatus)

        addHeader(
            "Auto Layout",
            detail: "The square is centred by a constraint, and .constant animates its constant. "
                + "Rotate while it plays: the track resizes and the square keeps its place and keeps going.")
        autoLayoutTrack.backgroundColor = .secondarySystemFill
        autoLayoutTrack.layer.cornerRadius = 8
        autoLayoutTrack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        autoLayoutSquare.backgroundColor = cyan
        autoLayoutSquare.layer.cornerRadius = 6
        autoLayoutSquare.layer.shadowColor = UIColor.black.cgColor
        autoLayoutSquare.layer.shadowOffset = CGSize(width: 0, height: 4)
        autoLayoutSquare.layer.shadowRadius = 4
        autoLayoutSquare.translatesAutoresizingMaskIntoConstraints = false
        autoLayoutTrack.addSubview(autoLayoutSquare)
        autoLayoutCentre = autoLayoutSquare.centerXAnchor.constraint(equalTo: autoLayoutTrack.centerXAnchor)
        NSLayoutConstraint.activate([
            autoLayoutCentre,
            autoLayoutSquare.centerYAnchor.constraint(equalTo: autoLayoutTrack.centerYAnchor),
            autoLayoutSquare.widthAnchor.constraint(equalToConstant: 32),
            autoLayoutSquare.heightAnchor.constraint(equalToConstant: 32),
        ])
        stack.addArrangedSubview(labelled(".constant(of: centreX, to: ±120)", autoLayoutTrack))

        addHeader(
            "Reduce Motion",
            detail: "Turn it on in Settings › Accessibility › Motion, then play: the squares jump, "
                + "while fades and colours still animate unless you pick Snap all.")
        reduceMotionPicker.addTarget(self, action: #selector(changeReduceMotionBehavior), for: .valueChanged)
        stack.addArrangedSubview(reduceMotionPicker)
        reduceMotionStatus.font = .preferredFont(forTextStyle: .footnote)
        reduceMotionStatus.textColor = .secondaryLabel
        reduceMotionStatus.numberOfLines = 0
        stack.addArrangedSubview(reduceMotionStatus)
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
        playGallery()
        playAutoLayout()
    }

    /// Everything but the Auto Layout row, which rotation leaves running.
    ///
    /// Pressed again while the gallery plays, it starts over from where every
    /// view is instead of putting them back. The old timelines are cancelled
    /// first: a newer animation takes a property over, but a later step of an
    /// old timeline would take it back.
    private func playGallery() {
        if running.contains(where: { $0.state == .running || $0.state == .paused }) {
            for handle in running { handle.cancel() }
            running.removeAll()
            resetControls()
        } else {
            resetGallery()
        }
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
        running.append(
            darkSwatch
                .animate(.background(.label), duration: 1.6)
                .wait(0.4)
                .animate(.background(pink), duration: 1.6))
        running.append(
            wideSwatch
                .animate(.background(p3Green, interpolation: .lch), duration: 1.6)
                .wait(0.4)
                .animate(.background(p3Red, interpolation: .lch), duration: 1.6))
        let width = timelineRow.bounds.width
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
        playInterrupt()
        playControls()
    }

    // MARK: Interrupting

    /// Cancels the previous run's handles, if any, but leaves the square where it is.
    private func playInterrupt() {
        for handle in interruptHandles { handle.cancel() }
        interruptHandles.removeAll()
        let end = interruptTrack.bounds.width - 38
        interruptStatus.text = "Running…"
        let handle =
            interruptSquare
            .animate(.x(end), .background(cyan), duration: 3.0).easeInOut(.sine)
            .onComplete { [weak self] in
                self?.interruptStatus.text = "The 3 s animation completed: it kept the colour change to the end"
            }
        interruptHandles.append(handle)
    }

    @objc private func moveLeft() {
        move(to: 6)
    }

    @objc private func moveRight() {
        move(to: interruptTrack.bounds.width - 38)
    }

    /// Nothing is cancelled: the newest animation of `x` owns it until it ends.
    private func move(to x: CGFloat) {
        interruptHandles.removeAll { $0.state == .finished }
        interruptHandles.append(interruptSquare.animate(.x(x), duration: 0.8).easeOut(.cubic))
    }

    private func resetInterrupt() {
        for handle in interruptHandles { handle.cancel() }
        interruptHandles.removeAll()
        interruptSquare.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        interruptSquare.backgroundColor = pink
        interruptStatus.text = "Idle"
    }

    // MARK: Auto Layout

    /// Swings the square right, left and back to the centre by animating the
    /// constant of the constraint that centres it. The offsets do not depend
    /// on the track's width, so the timeline stays valid through rotation.
    private func playAutoLayout() {
        resetAutoLayout()
        autoLayoutHandle =
            autoLayoutSquare
            .animate(.constant(of: autoLayoutCentre, to: 120), .custom(\.layer.shadowOpacity, to: 0.35), duration: 1.2)
            .easeInOut(.cubic)
            .animate(.constant(of: autoLayoutCentre, to: -120), duration: 1.6).easeInOut(.cubic)
            .animate(.constant(of: autoLayoutCentre, to: 0), .custom(\.layer.shadowOpacity, to: 0), duration: 1.2)
            .easeOut(.back)
    }

    private func resetAutoLayout() {
        autoLayoutHandle?.cancel()
        autoLayoutHandle = nil
        autoLayoutCentre.constant = 0
        autoLayoutSquare.layer.shadowOpacity = 0
    }

    // MARK: Controls

    @objc private func playControls() {
        startControls(looping: false)
    }

    @objc private func loopControls() {
        startControls(looping: true)
    }

    private func startControls(looping: Bool) {
        resetControls()
        view.layoutIfNeeded()
        let end = controlsTrack.bounds.width - 38
        let trip =
            controlsSquare
            .animate(.cornerRadius(16), duration: 0.3)
            .then()
            .animate(.x(end), duration: 1.2).easeInOut(.cubic)
            .animate(.rotation(degrees: 180), .background(cyan), duration: 0.6).delay(0.6)
            .parallel()
            .animate(.x(6), .rotation(degrees: 0), .background(pink), .cornerRadius(6), duration: 1.2)
            .easeInOut(.cubic).delay(0.4)
        let handle = looping ? trip.repeatForever() : trip.repeat(times: 2)
        controlsHandle = handle
        controlsLooping = looping
        controlsStatus.text = runningStatus
        updateControlButtons()
        Task { [weak self] in
            await handle.finished()
            // A newer Play replaced this handle; its own task reports on it.
            guard let self, self.controlsHandle === handle else { return }
            self.controlsStatus.text =
                handle.state == .cancelled
                ? "await finished() returned: cancelled, the square stays where it stopped"
                : "await finished() returned: finished, three round trips"
            self.updateControlButtons()
        }
    }

    @objc private func pauseControls() {
        controlsHandle?.pause()
        controlsStatus.text = "Paused"
        updateControlButtons()
    }

    @objc private func resumeControls() {
        controlsHandle?.resume()
        controlsStatus.text = runningStatus
        updateControlButtons()
    }

    /// `finished()` returns once the handle is cancelled, so the task started
    /// by Play updates the label.
    @objc private func cancelControls() {
        controlsHandle?.cancel()
    }

    private var runningStatus: String {
        controlsLooping ? "Looping until Cancel…" : "Running…"
    }

    private func updateControlButtons() {
        let state = controlsHandle?.state
        controlButtonViews["Pause"]?.isEnabled = state == .running
        controlButtonViews["Resume"]?.isEnabled = state == .paused
        controlButtonViews["Cancel"]?.isEnabled = state == .running || state == .paused
    }

    // MARK: Rotation

    /// Targets are computed from the track widths when Play is pressed, so a
    /// size change would leave squares short of or past the new track end.
    /// Kinieta sets frames directly and Auto Layout does not correct them:
    /// cancel, put everything back, and replay at the new size what was playing.
    /// The Auto Layout row is left alone: its constraint keeps it in place.
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let galleryWasPlaying = running.contains { $0.state == .running || $0.state == .paused }
        let controlsState = controlsHandle?.state
        resetGallery()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            if galleryWasPlaying {
                self.playGallery()
                if controlsState != .running && controlsState != .paused { self.resetControls() }
            } else if controlsState == .running || controlsState == .paused {
                self.startControls(looping: self.controlsLooping)
            }
            if controlsState == .paused { self.pauseControls() }
        }
    }

    /// Switches the engine between at most 60 Hz and up to 120 Hz. It takes
    /// effect on the next frame, so it can be flipped while the gallery plays.
    @objc private func toggleFrameRate() {
        let capped = Engine.shared.preferredFrameRateRange.maximum <= 60
        Engine.shared.preferredFrameRateRange =
            capped ? Engine.defaultFrameRateRange : CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        updateFrameRateButton()
    }

    private func updateFrameRateButton() {
        frameRateButton.title = Engine.shared.preferredFrameRateRange.maximum <= 60 ? "60 Hz" : "120 Hz"
    }

    /// Picks which properties snap under Reduce Motion. It applies to animations
    /// that start afterwards, so it takes effect on the next Play.
    @objc private func changeReduceMotionBehavior() {
        Engine.shared.reduceMotionBehavior = reduceMotionPicker.selectedSegmentIndex == 1 ? .snapAll : .snapMotion
        updateReduceMotionStatus()
    }

    @objc private func updateReduceMotionStatus() {
        let snapsAll = Engine.shared.reduceMotionBehavior == .snapAll
        reduceMotionPicker.selectedSegmentIndex = snapsAll ? 1 : 0
        guard UIAccessibility.isReduceMotionEnabled, Engine.shared.respectsReduceMotion else {
            reduceMotionStatus.text = "Reduce Motion is off: everything animates."
            return
        }
        reduceMotionStatus.text =
            snapsAll
            ? "Reduce Motion is on: every property snaps to its end state."
            : "Reduce Motion is on: movement snaps, fades and colours still animate."
    }

    @objc private func reset() {
        resetGallery()
        resetAutoLayout()
    }

    private func resetGallery() {
        for handle in running { handle.cancel() }
        running.removeAll()
        for entry in easingTracks {
            entry.square.transform = .identity
            entry.square.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
            entry.square.layer.cornerRadius = 6
        }
        for swatch in colourSwatches { swatch.view.backgroundColor = pink }
        darkSwatch.backgroundColor = pink
        wideSwatch.backgroundColor = p3Red
        for (i, square) in timelineSquares.enumerated() {
            square.frame = CGRect(x: 6 + CGFloat(i) * 44, y: 6, width: 32, height: 32)
            square.alpha = 1
        }
        timelineStatus.text = "Idle"
        resetInterrupt()
        resetControls()
    }

    private func resetControls() {
        let handle = controlsHandle
        controlsHandle = nil
        handle?.cancel()
        controlsSquare.transform = .identity
        controlsSquare.frame = CGRect(x: 6, y: 6, width: 32, height: 32)
        controlsSquare.backgroundColor = pink
        controlsSquare.layer.cornerRadius = 6
        controlsStatus.text = "Idle"
        updateControlButtons()
    }
}
