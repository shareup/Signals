import SwiftUI

let appCount = Signal(initialValue: 0)
let appMultiplier = Signal(initialValue: 2.0)

let appDoubled = computed { appCount.value * 2 }
let appScaled = computed { Double(appCount.value) * appMultiplier.value }

struct BasicExample: View {
    // NOTE: No @State needed! Just reference the signal's .value and they will be tracked
    var body: some View {
            VStack(spacing: 30) {
                GroupBox("Basic Signal") {
                    VStack(spacing: 15) {
                        Text("\(appCount.value)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.blue)

                        HStack(spacing: 15) {
                            Button("−") { appCount.value -= 1 }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)

                            Button("Reset") { appCount.value = 0 }
                                .buttonStyle(.bordered)

                            Button("+") { appCount.value += 1 }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                        }
                        .font(.title)
                    }
                    .padding()
                }

                GroupBox("Computed Signals") {
                    VStack(spacing: 15) {
                        HStack {
                            Text("Doubled:")
                            Spacer()
                            Text("\(appDoubled.value)")
                                .foregroundColor(.purple)
                        }

                        VStack {
                            HStack {
                                Text("Multiplier:")
                                Spacer()
                                Text(String(format: "%.1f", appMultiplier.value))
                            }

                            Slider(value: Binding(
                                get: { appMultiplier.value },
                                set: { appMultiplier.value = $0 }
                            ), in: 0.5...5.0, step: 0.5)

                            HStack {
                                Text("Scaled:")
                                Spacer()
                                Text(String(format: "%.1f", appScaled.value))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                }

                Text("✨ No @State needed!\nSignals live at module level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
    }
}

#Preview {
    BasicExample()
}
