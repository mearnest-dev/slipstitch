# Slipstitch API contract (v1)

Base URL: `/api/v1`. JSON in/out. Auth via `Authorization: Bearer <accessToken>`.
This document is the **shared contract**: backend modules implement it, the iOS
networking layer consumes it. Change it here first, then implement.

## Conventions

- IDs are cuid strings.
- Timestamps are ISO-8601 UTC strings.
- Errors: `{ "error": { "code": "string", "message": "string" } }` with appropriate HTTP status.
- Pagination: cursor-based. Requests take `?cursor=<id>&limit=<n>` (default limit 20, max 50).
  Responses: `{ "items": [...], "nextCursor": "string | null" }`.

## Auth — `/auth`

| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/auth/email/register` | `{ email, password, username, displayName }` | `AuthTokens` + `User` |
| POST | `/auth/email/login` | `{ email, password }` | `AuthTokens` + `User` |
| POST | `/auth/apple` | `{ identityToken, nonce, fullName? }` | `AuthTokens` + `User` |
| POST | `/auth/refresh` | `{ refreshToken }` | `AuthTokens` |
| POST | `/auth/logout` | `{ refreshToken }` | `204` |

`AuthTokens = { accessToken, refreshToken, accessTokenExpiresAt }`.
Access token TTL 15m, refresh token TTL 30d (rotating).

## Users — `/users`, `/me`

| Method | Path | Returns |
|---|---|---|
| GET | `/me` | `User` (self, includes email) |
| PATCH | `/me` | `User` — body `{ displayName?, bio?, avatarPhotoId?, defaultCommentsEnabled?, notificationsEnabled? }` |
| DELETE | `/me` | `204` — permanently deletes the account (cascades projects/photos/comments/follows/collections) |
| POST | `/me/onboarding` | `User` — body `{ interests?: string[], planningToMake?: string[] }`; stores interests, creates a `planning` project per planned make (idempotent by title), sets `onboardingCompleted` |
| GET | `/users/search` | `{ items: PublicUser[] }` — query `q` (username/displayName, case-insensitive), `limit` |
| GET | `/users/:id` | `PublicUser` (+ `isFollowing`, counts) |
| POST | `/users/:id/follow` | `{ following: true }` |
| DELETE | `/users/:id/follow` | `{ following: false }` |
| GET | `/users/:id/followers` | paginated `PublicUser[]` (cursor = last user id) |
| GET | `/users/:id/following` | paginated `PublicUser[]` (cursor = last user id) |
| GET | `/users/:id/projects` | paginated `Project[]` (public only unless self) |

## Projects (journal subjects) — `/projects`

A Project is a crochet make you journal about. It has progress logs and photos.

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/projects` | — | paginated own `Project[]` |
| POST | `/projects` | `ProjectInput` | `Project` |
| GET | `/projects/:id` | — | `Project` (+ `logs`, `photos`) |
| PATCH | `/projects/:id` | partial `ProjectInput` | `Project` |
| DELETE | `/projects/:id` | — | `204` |
| POST | `/projects/:id/logs` | `ProgressLogInput` | `ProgressLog` |
| GET | `/projects/:id/logs` | — | paginated `ProgressLog[]` |
| POST | `/projects/:id/like` | — | `{ liked: true, likeCount }` |
| DELETE | `/projects/:id/like` | — | `{ liked: false, likeCount }` |
| GET | `/projects/:id/comments` | — | paginated `Comment[]` (newest first) |
| POST | `/projects/:id/comments` | `{ body }` | `Comment` — `403 comments_disabled` when the project has comments off |
| DELETE | `/projects/:id/comments/:commentId` | — | `204` (comment author or project owner) |

```
ProjectInput   = { title, description?, craftType?, yarn?, yarnWeight?, hookSize?, status?, isPublic?, commentsEnabled?, coverPhotoId? }
ProgressLogInput = { note?, photoId?, rowCount?, hoursSpent? }
status ∈ "planning" | "inProgress" | "finished" | "frogged"
```

`commentsEnabled` defaults to the owner's account-level `defaultCommentsEnabled` when omitted on create.

## Collections — `/collections`

A Collection is a saved board. Items can be internal projects or external pins.

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/collections` | — | own `Collection[]` |
| POST | `/collections` | `{ name, description?, isPublic? }` | `Collection` |
| GET | `/collections/:id` | — | `Collection` (+ `items`) |
| PATCH | `/collections/:id` | partial | `Collection` |
| DELETE | `/collections/:id` | — | `204` |
| POST | `/collections/:id/items` | `{ projectId }` OR `{ externalPinId }` | `CollectionItem` |
| DELETE | `/collections/:id/items/:itemId` | — | `204` |

## Feed & search — `/feed`, `/search`

| Method | Path | Query | Returns |
|---|---|---|---|
| GET | `/feed` | `cursor,limit` | paginated `SearchResult[]` — recency stream; the first page leads with projects matching the viewer's onboarding interests, and the Ravelry slice searches those interests |
| GET | `/search` | `q, source, cursor, limit` | paginated `SearchResult[]` |

`source ∈ "internal" | "external" | "both"` (default `internal`).
- `internal` → public `Project`s matching `q` (title/tags/yarn).
- `external` → cached `ExternalPin`s (Pinterest/web). Phase-1 returns a stubbed/empty set behind a feature flag; integration lands later.
- `both` → interleaved.

`SearchResult = { kind: "project" | "pin", project?: Project, pin?: ExternalPin }`.

## Media — `/media`

Direct-to-R2 presigned uploads. Client requests a URL, PUTs the bytes to R2, then confirms.

| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/media/upload-url` | `{ contentType, fileSize }` | `{ photoId, uploadUrl, r2Key }` |
| POST | `/media/:photoId/complete` | `{ width, height, blurhash? }` | `Photo` |
| GET | `/media/:photoId` | — | `Photo` (with CDN `url`) |

`Photo = { id, url, width, height, blurhash, createdAt }`. `url` is the public R2/CDN URL.

## DTO shapes (mirror Prisma, see prisma/schema.prisma)

```
User       = { id, username, displayName, email, bio, avatarUrl,
               defaultCommentsEnabled, notificationsEnabled,
               interests: string[], onboardingCompleted, createdAt }
PublicUser = { id, username, displayName, bio, avatarUrl, projectCount, followerCount, followingCount, isFollowing }
Project    = { id, owner: PublicUser, title, description, craftType, yarn, yarnWeight, hookSize, status,
               isPublic, commentsEnabled, coverUrl, likeCount, liked, logCount, commentCount, createdAt, updatedAt }
Comment    = { id, projectId, author: PublicUser, body, createdAt }
ProgressLog = { id, projectId, note, photo?: Photo, rowCount, hoursSpent, createdAt }
Collection = { id, name, description, isPublic, coverUrl, itemCount, createdAt }
CollectionItem = { id, kind: "project" | "pin", project?: Project, pin?: ExternalPin, createdAt }
ExternalPin = { id, source, sourceUrl, imageUrl, title, createdAt }
```
