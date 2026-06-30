import SwiftUI
import Combine

// MARK: - Data Model
struct TimerItem: Identifiable {
    let id = UUID()
    var name: String = "New Timer"
    var minutes: Int = 2
    var seconds: Int = 0
    
    var totalSeconds: Int {
        return (minutes * 60) + seconds
    }
}

// MARK: - View Model
class MultiTimerViewModel: ObservableObject {
    @Published var timers: [TimerItem] = [TimerItem(name: "Warmup", minutes: 2, seconds: 0)]
    @Published var isRunning = false
    @Published var isSetup = true
    @Published var currentIndex = 0
    @Published var timeRemaining = 0
    @Published var showFinishedAlert = false
    
    private var timer: AnyCancellable?
    
    var currentTimer: TimerItem {
        timers[currentIndex]
    }
    
    func addTimer() {
        timers.append(TimerItem(name: "Timer \(timers.count + 1)"))
    }
    
    func deleteTimer(at offsets: IndexSet) {
        timers.remove(atOffsets: offsets)
        if timers.isEmpty {
            timers.append(TimerItem(name: "New Timer"))
        }
    }
    
    func startSequence(at index: Int) {
        currentIndex = index
        timeRemaining = timers[index].totalSeconds
        isSetup = false
        isRunning = true
        startTimer()
    }
    
    func startTimer() {
        isRunning = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }
    
    func resumeTimer() {
        startTimer()
    }
    
    func endSequence() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isSetup = true
    }
    
    func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            timer?.cancel()
            timer = nil
            isRunning = false
            showFinishedAlert = true
        }
    }
    
    func nextTimer() {
        if currentIndex < timers.count - 1 {
            currentIndex += 1
            timeRemaining = timers[currentIndex].totalSeconds
            startTimer()
        } else {
            endSequence()
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject var vm = MultiTimerViewModel()
    @State var itemToEdit: TimerItem?
    
    var body: some View {
        Group {
            if vm.isSetup {
                setupView
            } else {
                activeTimerView
            }
        }
        .sheet(item: $itemToEdit) { item in
            if let index = vm.timers.firstIndex(where: { $0.id == item.id }) {
                EditTimerView(timer: $vm.timers[index])
            }
        }
    }
    
    var setupView: some View {
        NavigationStack {
            List {
                Section("Your Sequence") {
                    ForEach($vm.timers) { $item in
                        HStack(spacing: 12) {
                            // Only this button starts the timer
                            Button(action: {
                                let index = vm.timers.firstIndex(where: { $0.id == item.id }) ?? 0
                                vm.startSequence(at: index)
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain) // Prevents the whole row from being a button
                            
                            // Name editing is now completely independent
                            TextField("Name", text: $item.name)
                                .textFieldStyle(.roundedBorder)
                            
                            // Only this button opens the duration editor
                            Button("\(item.minutes)m \(item.seconds)s") {
                                itemToEdit = item
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .onDelete(perform: vm.deleteTimer)
                    
                    Button(action: { vm.addTimer() }) {
                        Label("Add Timer", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Setup")
        }
    }
    
    var activeTimerView: some View {
        VStack(spacing: 30) {
            Text(vm.currentTimer.name)
                .font(.largeTitle.bold())
            
            Text(String(format: "%02d:%02d", vm.timeRemaining / 60, vm.timeRemaining % 60))
                .font(.system(size: 70, weight: .bold, design: .monospaced))
            
            HStack(spacing: 40) {
                Button {
                    vm.isRunning ? vm.pauseTimer() : vm.resumeTimer()
                } label: {
                    Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                
                Button {
                    vm.endSequence()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Timer Finished", isPresented: $vm.showFinishedAlert) {
            if vm.currentIndex < vm.timers.count - 1 {
                Button("Start Next") { vm.nextTimer() }
                Button("End", role: .cancel) { vm.endSequence() }
            } else {
                Button("Finish", role: .cancel) { vm.endSequence() }
            }
        }
    }
}

// MARK: - Sub-View for Editing Duration
struct EditTimerView: View {
    @Binding var timer: TimerItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Set Duration") {
                    HStack {
                        Picker("Minutes", selection: $timer.minutes) {
                            ForEach(0..<60, id: \.self) { Text("\($0)m").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        
                        Picker("Seconds", selection: $timer.seconds) {
                            ForEach(0..<60, id: \.self) { Text("\($0)s").tag($0) }
                        }
                        .pickerStyle(.wheel)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
