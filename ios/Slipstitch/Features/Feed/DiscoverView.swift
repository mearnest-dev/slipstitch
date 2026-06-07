import SwiftUI

/// Pinterest-style discovery: a masonry feed, plus search across internal
/// projects and external pins.
struct DiscoverView: View {
    @StateObject private var model = DiscoverModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if model.isSearching {
                    sourcePicker
                }
                content
            }
            .background(StitchTheme.Color.background)
            .navigationTitle("Discover")
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
        }
        .task { await model.loadFeedIfNeeded() }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: StitchTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(StitchTheme.Color.textSecondary)
            TextField("Search makes & pins", text: $model.query)
                .font(StitchTheme.Font.body)
                .foregroundStyle(StitchTheme.Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { model.submitSearch() }
                .onChange(of: model.query) { _, _ in model.queryChanged() }
            if !model.query.isEmpty {
                Button {
                    model.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                }
            }
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
        .padding(.vertical, StitchTheme.Spacing.sm)
        .background(StitchTheme.Color.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(StitchTheme.Color.divider, lineWidth: 1))
        .padding(.horizontal, StitchTheme.Spacing.md)
        .padding(.top, StitchTheme.Spacing.sm)
        .padding(.bottom, StitchTheme.Spacing.sm)
    }

    private var sourcePicker: some View {
        Picker("Source", selection: $model.source) {
            ForEach(SearchSource.allCases) { source in
                Text(source.label).tag(source)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, StitchTheme.Spacing.md)
        .padding(.bottom, StitchTheme.Spacing.sm)
        .onChange(of: model.source) { _, _ in model.sourceChanged() }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if model.isInitialLoading {
            loadingState
        } else if let error = model.errorMessage, model.cards.isEmpty {
            errorState(error)
        } else if model.cards.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            MasonryGrid(items: model.cards, spacing: StitchTheme.Spacing.md) { card in
                cardView(card)
                    .onAppear { model.cardAppeared(card) }
            }
            .padding(.horizontal, StitchTheme.Spacing.md)
            .padding(.top, StitchTheme.Spacing.xs)

            if model.isLoadingMore {
                ProgressView()
                    .tint(StitchTheme.Color.accent)
                    .padding(.vertical, StitchTheme.Spacing.lg)
            }
        }
        .refreshable { await model.refresh() }
    }

    @ViewBuilder
    private func cardView(_ card: DiscoverCard) -> some View {
        switch card.payload {
        case let .project(project):
            NavigationLink(value: project) {
                ProjectCardView(project: project, coverHeight: card.coverHeight)
            }
            .buttonStyle(.plain)
        case let .pin(pin):
            Link(destination: URL(string: pin.sourceUrl) ?? URL(string: "https://slipstitch.app")!) {
                ExternalPinCardView(pin: pin, coverHeight: card.coverHeight)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: States

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView().tint(StitchTheme.Color.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Spacer()
            Text(model.isSearching ? "🔍" : "🧶").font(.largeTitle)
            Text(model.isSearching ? "No results" : "Nothing here yet")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(model.isSearching
                 ? "Try another search or source."
                 : "Public makes will show up here.")
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Spacer()
            Text("Something went wrong")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, StitchTheme.Spacing.lg)
            Button("Try again") { Task { await model.refresh() } }
                .foregroundStyle(StitchTheme.Color.accent)
                .padding(.top, StitchTheme.Spacing.xs)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card model

/// A unit in the discovery grid: either an internal project or an external pin.
struct DiscoverCard: Identifiable, Hashable {
    enum Payload: Hashable {
        case project(Project)
        case pin(ExternalPin)
    }

    let id: String
    let payload: Payload
    /// Varied cover height for the Pinterest staggered look.
    let coverHeight: CGFloat

    init(project: Project) {
        self.id = "project-\(project.id)"
        self.payload = .project(project)
        self.coverHeight = DiscoverCard.height(forSeed: project.id)
    }

    init(pin: ExternalPin) {
        self.id = "pin-\(pin.id)"
        self.payload = .pin(pin)
        self.coverHeight = DiscoverCard.height(forSeed: pin.id)
    }

    /// Deterministic varied height between ~150 and ~280pt.
    private static func height(forSeed seed: String) -> CGFloat {
        let buckets: [CGFloat] = [150, 180, 210, 240, 280]
        let idx = abs(seed.hashValue) % buckets.count
        return buckets[idx]
    }
}

// MARK: - View model

@MainActor
final class DiscoverModel: ObservableObject {
    @Published var query = ""
    @Published var source: SearchSource = .internalSource

    @Published private(set) var cards: [DiscoverCard] = []
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?

    private var nextCursor: String?
    private var hasLoadedFeedOnce = false
    private var searchTask: Task<Void, Never>?
    /// Token used to ignore stale responses when query/source changes.
    private var requestToken = 0

    private let service = FeedService.shared

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Feed

    func loadFeedIfNeeded() async {
        guard !hasLoadedFeedOnce, !isSearching else { return }
        hasLoadedFeedOnce = true
        await loadFirstPage()
    }

    func refresh() async {
        await loadFirstPage()
    }

    private func loadFirstPage() async {
        let token = bumpToken()
        isInitialLoading = cards.isEmpty
        errorMessage = nil
        nextCursor = nil
        do {
            let newCards = try await fetchPage(cursor: nil)
            guard token == requestToken else { return }
            cards = newCards
        } catch {
            guard token == requestToken else { return }
            if cards.isEmpty { errorMessage = error.localizedDescription }
        }
        isInitialLoading = false
    }

    // MARK: Search input handling

    func queryChanged() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Back to feed.
            searchTask = Task { [weak self] in
                guard let self else { return }
                await self.loadFirstPage()
            }
            return
        }
        // Debounce search.
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.loadFirstPage()
        }
    }

    func submitSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.loadFirstPage()
        }
    }

    func sourceChanged() {
        guard isSearching else { return }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.loadFirstPage()
        }
    }

    func clearSearch() {
        query = ""
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.loadFirstPage()
        }
    }

    // MARK: Pagination

    func cardAppeared(_ card: DiscoverCard) {
        guard let idx = cards.firstIndex(of: card) else { return }
        // Trigger when within 4 of the end.
        guard idx >= cards.count - 4 else { return }
        loadMore()
    }

    private func loadMore() {
        guard !isLoadingMore, !isInitialLoading, let cursor = nextCursor else { return }
        let token = requestToken
        isLoadingMore = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let more = try await self.fetchPage(cursor: cursor)
                guard token == self.requestToken else { return }
                // Avoid duplicates.
                let existing = Set(self.cards.map(\.id))
                self.cards.append(contentsOf: more.filter { !existing.contains($0.id) })
            } catch {
                // Silently keep what we have on pagination failure.
            }
            self.isLoadingMore = false
        }
    }

    // MARK: Networking

    private func fetchPage(cursor: String?) async throws -> [DiscoverCard] {
        if isSearching {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let page = try await service.search(q: q, source: source, cursor: cursor)
            nextCursor = page.nextCursor
            return page.items.compactMap { result in
                if let project = result.project { return DiscoverCard(project: project) }
                if let pin = result.pin { return DiscoverCard(pin: pin) }
                return nil
            }
        } else {
            let page = try await service.fetchFeed(cursor: cursor)
            nextCursor = page.nextCursor
            return page.items.map { DiscoverCard(project: $0) }
        }
    }

    private func bumpToken() -> Int {
        requestToken += 1
        return requestToken
    }
}

// MARK: - Masonry grid

/// A two-column staggered grid. Items are distributed to whichever column is
/// currently shorter, producing a Pinterest-style layout.
struct MasonryGrid<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    var columns: Int = 2
    var spacing: CGFloat = 16
    let heightFor: ((Item) -> CGFloat)?
    @ViewBuilder let content: (Item) -> Content

    init(items: [Item],
         columns: Int = 2,
         spacing: CGFloat = 16,
         heightFor: ((Item) -> CGFloat)? = nil,
         @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.heightFor = heightFor
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(distributed.indices, id: \.self) { col in
                LazyVStack(spacing: spacing) {
                    ForEach(distributed[col]) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    /// Greedy distribution into the shortest column using estimated heights.
    private var distributed: [[Item]] {
        var buckets: [[Item]] = Array(repeating: [], count: max(columns, 1))
        var heights = Array(repeating: CGFloat(0), count: max(columns, 1))
        for item in items {
            // Pick the shortest column.
            var target = 0
            for col in 1..<buckets.count where heights[col] < heights[target] {
                target = col
            }
            buckets[target].append(item)
            heights[target] += estimatedHeight(item) + spacing
        }
        return buckets
    }

    private func estimatedHeight(_ item: Item) -> CGFloat {
        if let heightFor { return heightFor(item) }
        if let card = item as? DiscoverCard { return card.coverHeight + 70 }
        return 220
    }
}
