---
name: swift-expertise
description: Expert guidance for Swift development including SwiftUI, AppKit, async/await concurrency, memory management, MVVM architecture, and Apple AI integration. Use when writing Swift code, reviewing Swift patterns, building macOS/iOS apps, or integrating Apple frameworks.
---

# Swift Expertise

## Core Principles

1. **Protocol-oriented design** - Prefer protocols over inheritance
2. **Value types** - Use structs for data, classes for identity/shared state
3. **Immutability** - Default to `let`, use `var` only when mutation is required
4. **Type safety** - Leverage generics and associated types
5. **Expressiveness** - Use Swift idioms (guard, if-let, nil coalescing)

## SwiftUI Best Practices

### View Composition

```swift
// Break complex views into smaller components
struct ContentView: View {
    var body: some View {
        VStack {
            HeaderView()
            ItemListView()
            FooterView()
        }
    }
}

// Extract reusable view modifiers
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}
```

### State Management

| Property Wrapper | Use Case |
|-----------------|----------|
| `@State` | Local view state, value types |
| `@Binding` | Two-way connection to parent's state |
| `@StateObject` | Create and own an ObservableObject |
| `@ObservedObject` | Reference ObservableObject owned elsewhere |
| `@EnvironmentObject` | Shared app-wide observable state |
| `@Environment` | System values (colorScheme, dismiss, etc.) |
| `@Observable` (iOS 17+) | Modern observation without Combine |

### Performance

- Use `@ViewBuilder` for conditional view construction
- Avoid heavy computation in `body` - use computed properties or `.task`
- Use `EquatableView` or custom `Equatable` conformance to reduce redraws
- Prefer `LazyVStack`/`LazyHStack` for large lists

## Swift Concurrency

### Async/Await Patterns

```swift
// Structured concurrency
func fetchData() async throws -> [Item] {
    async let items = api.fetchItems()
    async let metadata = api.fetchMetadata()
    return try await merge(items, metadata)
}

// Task groups for dynamic parallelism
func processAll(_ urls: [URL]) async throws -> [Data] {
    try await withThrowingTaskGroup(of: Data.self) { group in
        for url in urls {
            group.addTask { try await fetch(url) }
        }
        return try await group.reduce(into: []) { $0.append($1) }
    }
}
```

### Actor Isolation

```swift
// Use actors for thread-safe mutable state
actor DataStore {
    private var cache: [String: Data] = [:]
    
    func get(_ key: String) -> Data? { cache[key] }
    func set(_ key: String, data: Data) { cache[key] = data }
}

// MainActor for UI updates
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    
    func load() async {
        items = await dataStore.fetchAll()
    }
}
```

### Sendable Conformance

- Mark types as `Sendable` when they can safely cross actor boundaries
- Use `@unchecked Sendable` only when you guarantee thread safety manually
- Prefer value types which are implicitly `Sendable`

## Memory Management

### ARC Best Practices

```swift
// Capture lists to prevent retain cycles
class ViewModel {
    var onComplete: (() -> Void)?
    
    func setup() {
        // Weak for optional callbacks
        onComplete = { [weak self] in
            self?.handleComplete()
        }
    }
}

// Unowned when lifetime is guaranteed
class Parent {
    let child: Child
    init() { child = Child(parent: self) }
}

class Child {
    unowned let parent: Parent
    init(parent: Parent) { self.parent = parent }
}
```

### Common Retain Cycle Sources

- Closures capturing `self` (use `[weak self]` or `[unowned self]`)
- Delegate properties (use `weak var delegate`)
- NotificationCenter observers (remove in `deinit`)
- Timer references (invalidate in `deinit`)
- Combine subscriptions (store in `Set<AnyCancellable>`)

## Architecture Patterns

### MVVM Structure

```
Feature/
├── Models/
│   └── Item.swift           # Data models
├── ViewModels/
│   └── ItemViewModel.swift  # Business logic, state
├── Views/
│   ├── ItemListView.swift   # SwiftUI views
│   └── ItemDetailView.swift
└── Services/
    └── ItemService.swift    # API/persistence
```

### ViewModel Pattern

```swift
@MainActor
class ItemViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    private let service: ItemServiceProtocol
    
    init(service: ItemServiceProtocol = ItemService()) {
        self.service = service
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await service.fetchItems()
        } catch {
            self.error = error
        }
    }
}
```

## AppKit Integration

### NSViewRepresentable for Custom Views

```swift
struct NSTextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
```

### macOS-Specific Patterns

- Use `NSPanel` for floating utility windows
- `NSPopover` for contextual UI
- `NSMenu` and `NSMenuItem` for context menus
- `NSPasteboard` for clipboard operations
- `NSWorkspace` for system integration

## Apple AI Integration

### Core ML

```swift
// Load and use ML model
class ImageClassifier {
    private let model: VNCoreMLModel
    
    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        let mlModel = try MyClassifier(configuration: config)
        model = try VNCoreMLModel(for: mlModel.model)
    }
    
    func classify(_ image: CGImage) async throws -> [Classification] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error { continuation.resume(throwing: error); return }
                let results = request.results as? [VNClassificationObservation] ?? []
                continuation.resume(returning: results.map { 
                    Classification(label: $0.identifier, confidence: $0.confidence)
                })
            }
            try? VNImageRequestHandler(cgImage: image).perform([request])
        }
    }
}
```

### Natural Language

```swift
import NaturalLanguage

// Sentiment analysis
func analyzeSentiment(_ text: String) -> Double? {
    let tagger = NLTagger(tagSchemes: [.sentimentScore])
    tagger.string = text
    let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
    return sentiment.flatMap { Double($0.rawValue) }
}

// Language detection
func detectLanguage(_ text: String) -> NLLanguage? {
    NLLanguageRecognizer.dominantLanguage(for: text)
}
```

### Speech & Vision

```swift
// Speech recognition
import Speech

func transcribe(audio url: URL) async throws -> String {
    let recognizer = SFSpeechRecognizer()
    let request = SFSpeechURLRecognitionRequest(url: url)
    return try await withCheckedThrowingContinuation { continuation in
        recognizer?.recognitionTask(with: request) { result, error in
            if let error { continuation.resume(throwing: error); return }
            if let result, result.isFinal {
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }
}
```

### App Intents (Shortcuts & Siri)

```swift
import AppIntents

struct OpenItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Item"
    static var description = IntentDescription("Opens a specific item")
    
    @Parameter(title: "Item Name")
    var itemName: String
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppState.shared.openItem(named: itemName)
        }
        return .result()
    }
}
```

## Error Handling

```swift
// Define domain-specific errors
enum AppError: LocalizedError {
    case networkFailure(underlying: Error)
    case invalidData(reason: String)
    case notFound(id: String)
    
    var errorDescription: String? {
        switch self {
        case .networkFailure(let error): return "Network error: \(error.localizedDescription)"
        case .invalidData(let reason): return "Invalid data: \(reason)"
        case .notFound(let id): return "Item not found: \(id)"
        }
    }
}

// Use Result type for synchronous operations
func parse(_ data: Data) -> Result<Model, AppError> {
    // ...
}

// Prefer throwing for async
func fetch() async throws -> Model {
    // ...
}
```

## Code Style

- Use trailing closure syntax for single closure parameters
- Prefer `guard` for early exits over nested `if` statements
- Use `defer` for cleanup that must happen regardless of exit path
- Favor `map`, `filter`, `compactMap` over manual loops when appropriate
- Use extensions to organize conformances and group related functionality
