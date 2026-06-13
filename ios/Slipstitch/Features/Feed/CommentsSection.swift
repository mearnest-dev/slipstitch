import SwiftUI

/// Comment thread shown on a project's detail page: list with one level of
/// replies, like hearts, a composer (with reply targeting), and delete (own
/// comments, or any comment when the viewer owns the project). Hidden
/// composer + notice when the project has comments turned off.
struct CommentsSection: View {
    let project: Project

    @EnvironmentObject private var session: SessionStore
    @StateObject private var model: CommentsModel

    init(project: Project) {
        self.project = project
        _model = StateObject(wrappedValue: CommentsModel(projectId: project.id))
    }

    private var commentsEnabled: Bool { project.commentsEnabled ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            Text("Comments")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)

            if commentsEnabled {
                composer
            } else {
                Text("Comments are turned off for this project.")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(.red)
            }

            commentList
        }
        .task { await model.loadIfNeeded() }
    }

    // MARK: Composer

    @ViewBuilder
    private var composer: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
            if let target = model.replyingTo {
                HStack(spacing: StitchTheme.Spacing.xs) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption2)
                    Text("Replying to @\(target.author.username)")
                        .font(StitchTheme.Font.caption)
                    Button {
                        model.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.caption)
                    }
                }
                .foregroundStyle(StitchTheme.Color.accent)
            }

            HStack(spacing: StitchTheme.Spacing.sm) {
                TextField(model.replyingTo == nil ? "Add a comment…" : "Write a reply…",
                          text: $model.draft, axis: .vertical)
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, StitchTheme.Spacing.md)
                    .padding(.vertical, StitchTheme.Spacing.sm)
                    .background(StitchTheme.Color.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))

                Button {
                    Task { await model.post() }
                } label: {
                    if model.isPosting {
                        ProgressView().tint(StitchTheme.Color.accent)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canPost ? StitchTheme.Color.accent : StitchTheme.Color.textSecondary)
                    }
                }
                .disabled(!canPost || model.isPosting)
            }
        }
    }

    private var canPost: Bool {
        !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: List

    @ViewBuilder
    private var commentList: some View {
        if model.isLoading && model.comments.isEmpty {
            ProgressView()
                .tint(StitchTheme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, StitchTheme.Spacing.md)
        } else if model.comments.isEmpty && commentsEnabled {
            Text("No comments yet — be the first!")
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
        } else {
            LazyVStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
                ForEach(model.comments) { comment in
                    VStack(alignment: .leading, spacing: StitchTheme.Spacing.sm) {
                        commentRow(comment, isReply: false)
                        if let replies = comment.replies, !replies.isEmpty {
                            VStack(alignment: .leading, spacing: StitchTheme.Spacing.sm) {
                                ForEach(replies) { reply in
                                    commentRow(reply, isReply: true)
                                }
                            }
                            .padding(.leading, 40)
                        }
                    }
                    .onAppear { model.commentAppeared(comment) }
                }
            }
            if model.isLoadingMore {
                ProgressView()
                    .tint(StitchTheme.Color.accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func commentRow(_ comment: Comment, isReply: Bool) -> some View {
        CommentRow(
            comment: comment,
            canDelete: canDelete(comment),
            canReply: commentsEnabled && !isReply,
            onLike: { Task { await model.toggleLike(comment) } },
            onReply: {
                model.replyingTo = comment
            },
            onDelete: { Task { await model.delete(comment) } }
        )
    }

    private func canDelete(_ comment: Comment) -> Bool {
        guard let me = session.currentUser?.id else { return false }
        return comment.author.id == me || project.owner.id == me
    }
}

// MARK: - Row

private struct CommentRow: View {
    let comment: Comment
    let canDelete: Bool
    let canReply: Bool
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: StitchTheme.Spacing.sm) {
            NavigationLink {
                UserProfileView(userId: comment.author.id)
            } label: {
                avatar
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: StitchTheme.Spacing.xs) {
                    Text(comment.author.displayName)
                        .font(StitchTheme.Font.caption.weight(.semibold))
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                    Text(comment.createdAt, style: .relative)
                        .font(StitchTheme.Font.caption)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                }
                Text(comment.body)
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textPrimary)

                if canReply {
                    Button("Reply", action: onReply)
                        .font(StitchTheme.Font.caption.weight(.semibold))
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Button(action: onLike) {
                VStack(spacing: 1) {
                    Image(systemName: comment.liked ? "heart.fill" : "heart")
                        .font(.footnote)
                        .foregroundStyle(comment.liked ? StitchTheme.Color.accent : StitchTheme.Color.textSecondary)
                    if comment.likeCount > 0 {
                        Text("\(comment.likeCount)")
                            .font(.caption2)
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            if canDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete comment", systemImage: "trash")
                }
            }
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = comment.author.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        StitchTheme.Color.pastel(for: comment.author.id)
                    }
                }
            } else {
                StitchTheme.Color.pastel(for: comment.author.id)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

// MARK: - Model

@MainActor
final class CommentsModel: ObservableObject {
    @Published var draft = ""
    @Published var replyingTo: Comment?
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isPosting = false
    @Published private(set) var errorMessage: String?

    private let projectId: String
    private var nextCursor: String?
    private var hasLoaded = false
    private var likeInFlight: Set<String> = []
    private let service = FeedService.shared

    init(projectId: String) {
        self.projectId = projectId
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        do {
            let page = try await service.comments(projectId: projectId)
            comments = page.items
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func commentAppeared(_ comment: Comment) {
        guard comment.id == comments.last?.id, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let page = try await service.comments(projectId: projectId, cursor: cursor)
                let existing = Set(comments.map(\.id))
                comments.append(contentsOf: page.items.filter { !existing.contains($0.id) })
                nextCursor = page.nextCursor
            } catch {
                // Keep what we have on pagination failure.
            }
            isLoadingMore = false
        }
    }

    func post() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isPosting else { return }
        isPosting = true
        errorMessage = nil
        // Replies always attach to the top-level comment of the thread.
        let parentId = replyingTo.map { $0.parentId ?? $0.id }
        do {
            let created = try await service.addComment(
                projectId: projectId, body: body, parentCommentId: parentId
            )
            if let parentId {
                comments = comments.map { top in
                    guard top.id == parentId else { return top }
                    return top.withReplies((top.replies ?? []) + [created])
                }
            } else {
                comments.insert(created, at: 0)
            }
            draft = ""
            replyingTo = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }

    func toggleLike(_ comment: Comment) async {
        guard !likeInFlight.contains(comment.id) else { return }
        likeInFlight.insert(comment.id)
        defer { likeInFlight.remove(comment.id) }

        let wasLiked = comment.liked
        // Optimistic flip.
        updateComment(id: comment.id) {
            $0.withLike(liked: !wasLiked, likeCount: $0.likeCount + (wasLiked ? -1 : 1))
        }
        do {
            let response = wasLiked
                ? try await service.unlikeComment(projectId: projectId, commentId: comment.id)
                : try await service.likeComment(projectId: projectId, commentId: comment.id)
            updateComment(id: comment.id) {
                $0.withLike(liked: response.liked, likeCount: response.likeCount)
            }
        } catch {
            updateComment(id: comment.id) {
                $0.withLike(liked: wasLiked, likeCount: max(0, $0.likeCount + (wasLiked ? 1 : -1)))
            }
        }
    }

    func delete(_ comment: Comment) async {
        errorMessage = nil
        do {
            try await service.deleteComment(projectId: projectId, commentId: comment.id)
            if let parentId = comment.parentId {
                comments = comments.map { top in
                    guard top.id == parentId else { return top }
                    return top.withReplies((top.replies ?? []).filter { $0.id != comment.id })
                }
            } else {
                comments.removeAll { $0.id == comment.id }
            }
            if replyingTo?.id == comment.id { replyingTo = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Apply a transform to the comment with `id`, wherever it sits in the tree.
    private func updateComment(id: String, _ transform: (Comment) -> Comment) {
        comments = comments.map { top in
            if top.id == id { return transform(top) }
            guard let replies = top.replies, replies.contains(where: { $0.id == id }) else { return top }
            return top.withReplies(replies.map { $0.id == id ? transform($0) : $0 })
        }
    }
}

// MARK: - Immutable-struct update helpers

private extension Comment {
    func withReplies(_ newReplies: [Comment]) -> Comment {
        Comment(id: id, projectId: projectId, parentId: parentId, author: author,
                body: body, likeCount: likeCount, liked: liked,
                replies: newReplies, createdAt: createdAt)
    }

    func withLike(liked newLiked: Bool, likeCount newCount: Int) -> Comment {
        Comment(id: id, projectId: projectId, parentId: parentId, author: author,
                body: body, likeCount: max(0, newCount), liked: newLiked,
                replies: replies, createdAt: createdAt)
    }
}
