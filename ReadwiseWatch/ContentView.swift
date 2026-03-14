import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var summaryText: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var navigationTitle: String = "Briefing"
    @State private var backgroundedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    formattedSummary(summaryText)

                    if let date = lastUpdated {
                        Divider()
                        Text(Self.relativeTimeString(from: date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("v1.1")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadSummary() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await loadSummary()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                if backgroundedAt == nil {
                    backgroundedAt = Date()
                }
            case .active:
                if let bg = backgroundedAt, Date().timeIntervalSince(bg) > 15 * 60 {
                    Task { await loadSummary() }
                }
                backgroundedAt = nil
            @unknown default:
                break
            }
        }
    }

    /// Render text with **bold** markdown parsed into actual bold styled lines.
    @ViewBuilder
    private func formattedSummary(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                Spacer().frame(height: 4)
            } else if let heading = extractBold(line) {
                // Line that is entirely a **bold heading**
                Text(heading)
                    .font(.headline)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
            } else {
                // Render inline **bold** within body text
                renderInlineBold(line)
                    .font(.body)
            }
        }
    }

    /// If the entire line is wrapped in **, return the inner text.
    private func extractBold(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && trimmed.count > 4 {
            let inner = String(trimmed.dropFirst(2).dropLast(2))
            if !inner.contains("**") {
                return inner
            }
        }
        return nil
    }

    /// Parse inline **bold** segments and return styled Text.
    private func renderInlineBold(_ line: String) -> Text {
        var result = Text("")
        var remaining = line[line.startIndex...]

        while let boldStart = remaining.range(of: "**") {
            let before = remaining[remaining.startIndex..<boldStart.lowerBound]
            if !before.isEmpty {
                result = result + Text(before)
            }

            let afterOpen = boldStart.upperBound
            if let boldEnd = remaining[afterOpen...].range(of: "**") {
                let boldContent = remaining[afterOpen..<boldEnd.lowerBound]
                result = result + Text(boldContent).bold()
                remaining = remaining[boldEnd.upperBound...]
            } else {
                result = result + Text(remaining[boldStart.lowerBound...])
                remaining = remaining[remaining.endIndex...]
            }
        }

        if !remaining.isEmpty {
            result = result + Text(remaining)
        }

        return result
    }

    /// Static relative time string (not live-updating).
    private static func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadSummary() async {
        isLoading = true
        errorMessage = nil

        do {
            let service = ReadwiseAPIService()
            if let doc = try await service.fetchLatestWatchSummary() {
                summaryText = doc.plainTextContent
                lastUpdated = doc.publishedAt
                // Show generation time in the nav title
                if let date = doc.publishedAt {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    navigationTitle = "News at \(formatter.string(from: date))"
                }
            } else {
                errorMessage = "No briefing found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
