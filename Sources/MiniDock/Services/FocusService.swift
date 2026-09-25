import Foundation
import Combine
import AppKit

public enum FocusMode: String, CaseIterable, Identifiable {
    case focus25 = "25m Sprint"
    case focus50 = "50m Deep Work"
    case focus90 = "90m Flow State"
    case shortBreak = "5m Break"
    case longBreak = "15m Rest"
    
    public var id: String { rawValue }
    
    public var durationSeconds: Int {
        switch self {
        case .focus25: return 25 * 60
        case .focus50: return 50 * 60
        case .focus90: return 90 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
    
    public var defaultLabel: String {
        switch self {
        case .focus25: return "Focus"
        case .focus50: return "Deep Work"
        case .focus90: return "Flow State"
        case .shortBreak: return "Break"
        case .longBreak: return "Rest"
        }
    }

    public var iconName: String {
        switch self {
        case .focus25: return "bolt.fill"
        case .focus50: return "target"
        case .focus90: return "waveform.path.ecg"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .focus25: return "25m Sprint"
        case .focus50: return "50m Deep"
        case .focus90: return "90m Flow"
        case .shortBreak: return "5m Break"
        case .longBreak: return "15m Rest"
        }
    }

    public var isBreak: Bool {
        switch self {
        case .shortBreak, .longBreak: return true
        default: return false
        }
    }
}

@MainActor
public final class FocusService: ObservableObject {
    public static let shared = FocusService()
    
    @Published public var currentMode: FocusMode = .focus25
    @Published public var remainingSeconds: Int = 25 * 60
    @Published public var totalSeconds: Int = 25 * 60
    @Published public var isRunning: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var taskLabel: String = "Deep Work"
    @Published public var completedSessions: Int = 0
    
    private var timer: AnyCancellable?
    
    private init() {
        self.remainingSeconds = currentMode.durationSeconds
        self.totalSeconds = currentMode.durationSeconds
    }
    
    public var progress: Double {
        guard totalSeconds > 0 else { return 0.0 }
        let elapsed = totalSeconds - remainingSeconds
        return min(max(Double(elapsed) / Double(totalSeconds), 0.0), 1.0)
    }
    
    public var formattedRemainingTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        if minutes >= 60 {
            return String(format: "%dh %02dm", minutes / 60, minutes % 60)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var statusText: String {
        if !isRunning && !isPaused {
            return "\(currentMode.defaultLabel) \(currentMode.durationSeconds / 60)m"
        } else if isPaused {
            return "Paused (\(formattedRemainingTime))"
        } else {
            return "\(taskLabel) · \(formattedRemainingTime)"
        }
    }
    
    public func start(mode: FocusMode? = nil) {
        if let mode = mode {
            self.currentMode = mode
            self.totalSeconds = mode.durationSeconds
            self.remainingSeconds = mode.durationSeconds
            self.taskLabel = mode.defaultLabel
        }
        
        self.isRunning = true
        self.isPaused = false
        
        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    public func pause() {
        isRunning = false
        isPaused = true
        timer?.cancel()
        timer = nil
    }
    
    public func resume() {
        guard isPaused else { return }
        isRunning = true
        isPaused = false
        
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    public func togglePlayPause() {
        if isRunning {
            pause()
        } else if isPaused {
            resume()
        } else {
            start()
        }
    }
    
    public func reset() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
        remainingSeconds = currentMode.durationSeconds
        totalSeconds = currentMode.durationSeconds
    }
    
    public func switchMode(_ mode: FocusMode) {
        self.currentMode = mode
        self.taskLabel = mode.defaultLabel
        reset()
    }
    
    public func extendTime(by minutes: Int) {
        self.remainingSeconds += minutes * 60
        self.totalSeconds += minutes * 60
    }
    
    public func skipSession() {
        completeSession()
    }
    
    private func tick() {
        guard remainingSeconds > 0 else {
            completeSession()
            return
        }
        remainingSeconds -= 1
    }
    
    public func startCustomDuration(minutes: Int, label: String = "Deep Work") {
        self.totalSeconds = minutes * 60
        self.remainingSeconds = minutes * 60
        self.taskLabel = label
        self.isRunning = true
        self.isPaused = false
        
        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        
        TransientCapsuleManager.shared.post(
            icon: "timer",
            title: "Focus Started",
            detail: "\(label) · \(minutes)m",
            color: .blue,
            duration: 3.0
        )
    }
    
    private func completeSession() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
        
        if currentMode == .focus25 || currentMode == .focus50 {
            completedSessions += 1
            NSSound(named: "Glass")?.play()
            TransientCapsuleManager.shared.post(
                icon: "sparkles",
                title: "Focus Complete!",
                detail: "Great work · Take a 5m break",
                color: .green,
                duration: 4.5
            )
            // Suggest break
            switchMode(.shortBreak)
        } else {
            NSSound(named: "Hero")?.play()
            switchMode(.focus25)
        }
    }
}
