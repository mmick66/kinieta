import AppKit
import Kinieta

/// The macOS gallery: the iOS demo's easing tracks, colour spaces, composed
/// timeline, controls, interrupting and Auto Layout rows, animating `NSView`s.
///
/// Geometry is in each track's coordinates, from the bottom left: a 32 pt
/// square at `y` 6 sits in the middle of a 44 pt track.
final class DemoViewController: NSViewController {

    private let stack = NSStackView()
    private var easingTracks: [(easing: Easing, square: NSView, track: NSView)] = []
    private var colourSwatches: [(mode: ColorInterpolation, view: NSView)] = []
    private let darkSwatch = NSView()
    private let wideSwatch = NSView()
    private let timelineRow = NSView()
    private var timelineSquares: [NSView] = []
    private let timelineStatus = NSTextField(labelWithString: "Idle")
    private var running: [Kinieta] = []
    private let controlsTrack = TrackView()
    private let controlsSquare = NSView()
    private let controlsStatus = NSTextField(wrappingLabelWithString: "Idle")
    private var controlsHandle: Kinieta?
    /// Whether the latest run of the Controls row was started by Loop.
    private var controlsLooping = false
    private var controlButtons: [String: NSButton] = [:]
    private let interruptTrack = TrackView()
    private let interruptSquare = NSView()
    private let interruptStatus = NSTextField(wrappingLabelWithString: "Idle")
    private var interruptHandles: [Kinieta] = []
    private let autoLayoutTrack = TrackView()
    private let autoLayoutSquare = NSView()
    private var autoLayoutCentre: NSLayoutConstraint!
    private var autoLayoutHandle: Kinieta?

    private let pink = NSColor(srgbRed: 1.00, green: 0.44, blue: 0.75, alpha: 1.00)
    private let cyan = NSColor(srgbRed: 0.00, green: 0.80, blue: 0.90, alpha: 1.00)
    private let p3Red = NSColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)
    private let p3Green = NSColor(displayP3Red: 0, green: 1, blue: 0, alpha: 1)
    private let home = NSRect(x: 6, y: 6, width: 32, height: 32)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 720))
        buildLayout()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // `-autoplay` starts the gallery on launch, for screenshots and recordings.
        if ProcessInfo.processInfo.arguments.contains("-autoplay") { playAll() }
    }

    // MARK: Layout

    private func buildLayout() {
        let toolbar = NSStackView(views: [
            NSButton(title: "Play", target: self, action: #selector(playAll)),
            NSButton(title: "Reset", target: self, action: #selector(reset)),
        ])
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -32),
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
            let track = TrackView()
            let square = makeSquare(color: pink)
            square.frame = home
            track.addSubview(square)
            addRow(labelled(name, track))
            easingTracks.append((easing, square, track))
        }

        addHeader("Colour", detail: "Pink to cyan through three colour spaces. LCH is the default.")
        for (name, mode) in [("rgb", ColorInterpolation.rgb), ("hsb", .hsb), ("lch", .lch)] {
            let swatch = makeSquare(color: pink)
            swatch.layer?.cornerRadius = 8
            swatch.heightAnchor.constraint(equalToConstant: 36).isActive = true
            addRow(labelled(name, swatch))
            colourSwatches.append((mode, swatch))
        }
        // A dark panel in a light app: `.labelColor` is white here, so the swatch
        // should brighten all the way instead of darkening and then snapping to white.
        let panel = TrackView(fill: .windowBackgroundColor, height: 48)
        panel.appearance = NSAppearance(named: .darkAqua)
        darkSwatch.wantsLayer = true
        darkSwatch.layer?.backgroundColor = pink.cgColor
        darkSwatch.layer?.cornerRadius = 6
        darkSwatch.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(darkSwatch)
        NSLayoutConstraint.activate([
            darkSwatch.topAnchor.constraint(equalTo: panel.topAnchor, constant: 6),
            darkSwatch.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 6),
            darkSwatch.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -6),
            darkSwatch.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -6),
        ])
        addRow(labelled("lch to .labelColor, dark appearance", panel))
        // Both ends are outside sRGB. On a wide-colour display the frames in between
        // stay as saturated, so there is no jump on the last frame.
        wideSwatch.wantsLayer = true
        wideSwatch.layer?.backgroundColor = p3Red.cgColor
        wideSwatch.layer?.cornerRadius = 8
        wideSwatch.heightAnchor.constraint(equalToConstant: 36).isActive = true
        addRow(labelled("lch, Display P3 red to green", wideSwatch))

        addHeader(
            "Timeline", detail: "The first square moves, then the other two move together, then one completion fires.")
        timelineRow.heightAnchor.constraint(equalToConstant: 44).isActive = true
        for (i, color) in [pink, cyan, .systemIndigo].enumerated() {
            let square = makeSquare(color: color)
            square.frame = home.offsetBy(dx: CGFloat(i) * 44, dy: 0)
            timelineRow.addSubview(square)
            timelineSquares.append(square)
        }
        addRow(timelineRow)
        addRow(status(timelineStatus))

        addHeader(
            "Controls",
            detail: "One handle: round the corners, then() move out while a delayed spin and colour change run in "
                + "parallel(), come back after a delay, repeat twice, or with Loop repeatForever() until Cancel. "
                + "The label is set when await finished() returns.")
        controlsSquare.frame = home
        controlsSquare.wantsLayer = true
        controlsSquare.layer?.backgroundColor = pink.cgColor
        controlsSquare.layer?.cornerRadius = 6
        controlsTrack.addSubview(controlsSquare)
        addRow(controlsTrack)
        let buttons = NSStackView()
        buttons.distribution = .fillEqually
        for (title, action) in [
            ("Play", #selector(playControls)), ("Loop", #selector(loopControls)), ("Pause", #selector(pauseControls)),
            ("Resume", #selector(resumeControls)), ("Cancel", #selector(cancelControls)),
        ] {
            let button = NSButton(title: title, target: self, action: action)
            buttons.addArrangedSubview(button)
            controlButtons[title] = button
        }
        addRow(buttons)
        addRow(status(controlsStatus))
        updateControlButtons()

        addHeader(
            "Interrupting",
            detail: "Play starts a 3 s move with a colour change. Click Left or Right while it runs: "
                + "the new animation takes x over from where the square is, and the colour keeps going.")
        interruptSquare.frame = home
        interruptSquare.wantsLayer = true
        interruptSquare.layer?.backgroundColor = pink.cgColor
        interruptSquare.layer?.cornerRadius = 6
        interruptTrack.addSubview(interruptSquare)
        addRow(interruptTrack)
        let directions = NSStackView(views: [
            NSButton(title: "Left", target: self, action: #selector(moveSquareLeft)),
            NSButton(title: "Right", target: self, action: #selector(moveSquareRight)),
        ])
        directions.distribution = .fillEqually
        addRow(directions)
        addRow(status(interruptStatus))

        addHeader(
            "Auto Layout",
            detail: "The square is centred by a constraint, and .constant animates its constant, "
                + "calling layoutSubtreeIfNeeded() every frame.")
        autoLayoutSquare.wantsLayer = true
        autoLayoutSquare.layer?.backgroundColor = cyan.cgColor
        autoLayoutSquare.layer?.cornerRadius = 6
        autoLayoutSquare.layer?.shadowColor = NSColor.black.cgColor
        // A layer's geometry is not flipped: a negative height casts the shadow downwards.
        autoLayoutSquare.layer?.shadowOffset = CGSize(width: 0, height: -4)
        autoLayoutSquare.layer?.shadowRadius = 4
        // AppKit masks a layer-backed view to its bounds, which would hide the shadow.
        autoLayoutSquare.clipsToBounds = false
        autoLayoutSquare.translatesAutoresizingMaskIntoConstraints = false
        autoLayoutTrack.addSubview(autoLayoutSquare)
        autoLayoutCentre = autoLayoutSquare.centerXAnchor.constraint(equalTo: autoLayoutTrack.centerXAnchor)
        NSLayoutConstraint.activate([
            autoLayoutCentre,
            autoLayoutSquare.centerYAnchor.constraint(equalTo: autoLayoutTrack.centerYAnchor),
            autoLayoutSquare.widthAnchor.constraint(equalToConstant: 32),
            autoLayoutSquare.heightAnchor.constraint(equalToConstant: 32),
        ])
        addRow(labelled(".constant(centreX, to: ±120)", autoLayoutTrack))

        addHeader(
            "Reduce Motion",
            detail: "Turn on System Settings › Accessibility › Display › Reduce motion, then play: "
                + "the squares jump, while fades and colours still animate.")
    }

    /// Adds `row` to the stack at its full width.
    private func addRow(_ row: NSView) {
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addHeader(_ title: String, detail: String) {
        let heading = NSTextField(labelWithString: title)
        heading.font = .preferredFont(forTextStyle: .title2)
        let sub = NSTextField(wrappingLabelWithString: detail)
        sub.font = .preferredFont(forTextStyle: .footnote)
        sub.textColor = .secondaryLabelColor
        let group = NSStackView(views: [heading, sub])
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 2
        if let last = stack.arrangedSubviews.last { stack.setCustomSpacing(24, after: last) }
        addRow(group)
    }

    private func labelled(_ text: String, _ content: NSView) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        let group = NSStackView(views: [label, content])
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 4
        content.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        return group
    }

    private func status(_ label: NSTextField) -> NSTextField {
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeSquare(color: NSColor) -> NSView {
        let square = NSView()
        square.wantsLayer = true
        square.layer?.backgroundColor = color.cgColor
        square.layer?.cornerRadius = 6
        return square
    }

    // MARK: Actions

    @objc private func playAll() {
        playGallery()
        playAutoLayout()
    }

    /// Everything but the Auto Layout row.
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
        view.layoutSubtreeIfNeeded()
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
                .animate(.background(.labelColor), duration: 1.6)
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
        timelineStatus.stringValue = "Running…"
        let group = Kinieta.group(first, second, third) { [weak self] in
            self?.timelineStatus.stringValue = "Done: three timelines, one completion"
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
        interruptStatus.stringValue = "Running…"
        let handle =
            interruptSquare
            .animate(.x(end), .background(cyan), duration: 3.0).easeInOut(.sine)
            .onComplete { [weak self] in
                self?.interruptStatus.stringValue = "The 3 s animation completed: it kept the colour change to the end"
            }
        interruptHandles.append(handle)
    }

    @objc private func moveSquareLeft() {
        move(to: 6)
    }

    @objc private func moveSquareRight() {
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
        interruptSquare.frame = home
        interruptSquare.layer?.backgroundColor = pink.cgColor
        interruptStatus.stringValue = "Idle"
    }

    // MARK: Auto Layout

    /// Swings the square right, left and back to the centre by animating the
    /// constant of the constraint that centres it, with its shadow fading in
    /// and out through a key path.
    private func playAutoLayout() {
        resetAutoLayout()
        autoLayoutHandle =
            autoLayoutSquare
            .animate(.constant(autoLayoutCentre, to: 120), .custom(\.layer!.shadowOpacity, to: 0.35), duration: 1.2)
            .easeInOut(.cubic)
            .animate(.constant(autoLayoutCentre, to: -120), duration: 1.6).easeInOut(.cubic)
            .animate(.constant(autoLayoutCentre, to: 0), .custom(\.layer!.shadowOpacity, to: 0), duration: 1.2)
            .easeOut(.back)
    }

    private func resetAutoLayout() {
        autoLayoutHandle?.cancel()
        autoLayoutHandle = nil
        autoLayoutCentre.constant = 0
        autoLayoutSquare.layer?.shadowOpacity = 0
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
        view.layoutSubtreeIfNeeded()
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
        controlsStatus.stringValue = runningStatus
        updateControlButtons()
        Task { [weak self] in
            await handle.finished()
            // A newer Play replaced this handle; its own task reports on it.
            guard let self, self.controlsHandle === handle else { return }
            self.controlsStatus.stringValue =
                handle.state == .cancelled
                ? "await finished() returned: cancelled, the square stays where it stopped"
                : "await finished() returned: finished, three round trips"
            self.updateControlButtons()
        }
    }

    @objc private func pauseControls() {
        controlsHandle?.pause()
        controlsStatus.stringValue = "Paused"
        updateControlButtons()
    }

    @objc private func resumeControls() {
        controlsHandle?.resume()
        controlsStatus.stringValue = runningStatus
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
        controlButtons["Pause"]?.isEnabled = state == .running
        controlButtons["Resume"]?.isEnabled = state == .paused
        controlButtons["Cancel"]?.isEnabled = state == .running || state == .paused
    }

    // MARK: Reset

    @objc private func reset() {
        resetGallery()
        resetAutoLayout()
    }

    private func resetGallery() {
        for handle in running { handle.cancel() }
        running.removeAll()
        for entry in easingTracks {
            entry.square.frameRotation = 0
            entry.square.frame = home
            entry.square.layer?.cornerRadius = 6
        }
        for swatch in colourSwatches { swatch.view.layer?.backgroundColor = pink.cgColor }
        darkSwatch.layer?.backgroundColor = pink.cgColor
        wideSwatch.layer?.backgroundColor = p3Red.cgColor
        for (i, square) in timelineSquares.enumerated() {
            square.frame = home.offsetBy(dx: CGFloat(i) * 44, dy: 0)
            square.alphaValue = 1
        }
        timelineStatus.stringValue = "Idle"
        resetInterrupt()
        resetControls()
    }

    private func resetControls() {
        let handle = controlsHandle
        controlsHandle = nil
        handle?.cancel()
        controlsSquare.frameRotation = 0
        controlsSquare.frame = home
        controlsSquare.layer?.backgroundColor = pink.cgColor
        controlsSquare.layer?.cornerRadius = 6
        controlsStatus.stringValue = "Idle"
        updateControlButtons()
    }
}

/// A rounded track whose fill follows the appearance: a layer holds a
/// `CGColor`, so a dynamic colour is resolved again in `updateLayer()`.
private final class TrackView: NSView {

    private let fill: NSColor

    init(fill: NSColor = .quaternaryLabelColor, height: CGFloat = 44) {
        self.fill = fill
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = fill.cgColor
    }
}

/// A scroll view's document view that lays its content out from the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
