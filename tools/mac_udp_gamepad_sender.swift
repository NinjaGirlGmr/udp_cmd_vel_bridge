import Foundation
import GameController
import Network

struct Settings {
    let host: String
    let port: UInt16
    let linearScale: Double
    let angularScale: Double
    let turboLinearScale: Double
    let turboAngularScale: Double
    let period: TimeInterval

    static func parse() -> Settings {
        var host = "10.0.0.163"
        var port: UInt16 = 8765
        var linearScale = 0.5
        var angularScale = 1.2
        var turboLinearScale = 1.0
        var turboAngularScale = 2.0
        var period = 0.05

        let args = Array(CommandLine.arguments.dropFirst())
        var index = 0
        while index < args.count {
            let arg = args[index]
            func nextValue() -> String {
                precondition(index + 1 < args.count, "Missing value for \(arg)")
                index += 1
                return args[index]
            }

            switch arg {
            case "--host":
                host = nextValue()
            case "--port":
                port = UInt16(nextValue()) ?? port
            case "--linear-scale":
                linearScale = Double(nextValue()) ?? linearScale
            case "--angular-scale":
                angularScale = Double(nextValue()) ?? angularScale
            case "--turbo-linear-scale":
                turboLinearScale = Double(nextValue()) ?? turboLinearScale
            case "--turbo-angular-scale":
                turboAngularScale = Double(nextValue()) ?? turboAngularScale
            case "--rate":
                let hz = Double(nextValue()) ?? 20.0
                if hz > 0.0 {
                    period = 1.0 / hz
                }
            case "--help":
                print("""
                Usage: swift mac_udp_gamepad_sender.swift [options]

                  --host 10.0.0.163
                  --port 8765
                  --linear-scale 0.5
                  --angular-scale 1.2
                  --turbo-linear-scale 1.0
                  --turbo-angular-scale 2.0
                  --rate 20
                """)
                exit(0)
            default:
                fputs("Unknown argument: \(arg)\n", stderr)
                exit(2)
            }
            index += 1
        }

        return Settings(
            host: host,
            port: port,
            linearScale: linearScale,
            angularScale: angularScale,
            turboLinearScale: turboLinearScale,
            turboAngularScale: turboAngularScale,
            period: period
        )
    }
}

final class TeleopSender {
    private let settings: Settings
    private let connection: NWConnection
    private var controller: GCController?
    private let queue = DispatchQueue(label: "mac_udp_gamepad_sender")

    init(settings: Settings) {
        self.settings = settings
        self.connection = NWConnection(
            host: NWEndpoint.Host(settings.host),
            port: NWEndpoint.Port(rawValue: settings.port)!,
            using: .udp
        )
    }

    func run() {
        connection.stateUpdateHandler = { state in
            print("UDP connection state: \(state)")
        }
        connection.start(queue: queue)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        GCController.startWirelessControllerDiscovery {}
        attachFirstControllerIfAvailable()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: settings.period)
        timer.setEventHandler { [weak self] in
            self?.sendCurrentState()
        }
        timer.resume()

        print("Waiting for Xbox controller. Press Ctrl+C to exit.")
        dispatchMain()
    }

    @objc
    private func handleControllerDidConnect(_ notification: Notification) {
        if let pad = notification.object as? GCController {
            controller = pad
            print("Controller connected: \(pad.vendorName ?? "unknown")")
        }
    }

    @objc
    private func handleControllerDidDisconnect(_ notification: Notification) {
        if let pad = notification.object as? GCController, pad == controller {
            controller = nil
        }
        print("Controller disconnected")
    }

    private func attachFirstControllerIfAvailable() {
        if let first = GCController.controllers().first {
            controller = first
            print("Using controller: \(first.vendorName ?? "unknown")")
        }
    }

    private func sendCurrentState() {
        guard let controller = controller else {
            return
        }

        let profile = controller.extendedGamepad
        guard let profile else {
            return
        }

        let enablePressed = profile.leftShoulder.isPressed
        let turboPressed = profile.rightShoulder.isPressed

        let linearScale = turboPressed ? settings.turboLinearScale : settings.linearScale
        let angularScale = turboPressed ? settings.turboAngularScale : settings.angularScale

        let linearX = enablePressed || turboPressed
            ? Double(profile.leftThumbstick.yAxis.value) * linearScale
            : 0.0
        let angularZ = enablePressed || turboPressed
            ? Double(-profile.leftThumbstick.xAxis.value) * angularScale
            : 0.0

        let message = [
            "linear_x": linearX,
            "angular_z": angularZ,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: message) else {
            return
        }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error {
                fputs("UDP send error: \(error)\n", stderr)
            }
        })
    }
}

let settings = Settings.parse()
let sender = TeleopSender(settings: settings)
sender.run()
