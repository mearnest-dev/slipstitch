import type { Prisma } from "@prisma/client";
import { publicUrl } from "../../lib/r2.js";

// Local serializers for the feed + search module. These intentionally do NOT
// import from other modules (projects/users/media own their own copies); the
// shapes here mirror the DTOs in docs/API.md exactly.

// ---- Photo ----------------------------------------------------------------

const photoWithUrl = {
  id: true,
  r2Key: true,
  width: true,
  height: true,
  blurhash: true,
  createdAt: true,
} satisfies Prisma.PhotoSelect;

type PhotoRow = Prisma.PhotoGetPayload<{ select: typeof photoWithUrl }>;

export interface PhotoDTO {
  id: string;
  url: string;
  width: number | null;
  height: number | null;
  blurhash: string | null;
  createdAt: string;
}

export function serializePhoto(photo: PhotoRow): PhotoDTO {
  return {
    id: photo.id,
    url: publicUrl(photo.r2Key),
    width: photo.width,
    height: photo.height,
    blurhash: photo.blurhash,
    createdAt: photo.createdAt.toISOString(),
  };
}

// ---- PublicUser -----------------------------------------------------------

export const publicUserSelect = {
  id: true,
  username: true,
  displayName: true,
  bio: true,
  avatarPhoto: { select: photoWithUrl },
  _count: { select: { projects: true, followers: true, following: true } },
} satisfies Prisma.UserSelect;

type PublicUserRow = Prisma.UserGetPayload<{ select: typeof publicUserSelect }>;

export interface PublicUserDTO {
  id: string;
  username: string;
  displayName: string;
  bio: string | null;
  avatarUrl: string | null;
  projectCount: number;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
}

export function serializePublicUser(user: PublicUserRow): PublicUserDTO {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    bio: user.bio,
    avatarUrl: user.avatarPhoto ? publicUrl(user.avatarPhoto.r2Key) : null,
    projectCount: user._count.projects,
    followerCount: user._count.followers,
    followingCount: user._count.following,
    // Feed/search context does not resolve per-viewer follow state; default false.
    isFollowing: false,
  };
}

// ---- Project --------------------------------------------------------------

// Selection used everywhere the feed/search module returns a Project DTO. The
// `likes` relation is filtered to the viewer (if any) so `liked` can be derived
// without a second query.
export function projectSelect(viewerId: string | undefined) {
  return {
    id: true,
    title: true,
    description: true,
    craftType: true,
    yarn: true,
    hookSize: true,
    status: true,
    isPublic: true,
    createdAt: true,
    updatedAt: true,
    owner: { select: publicUserSelect },
    cover: { select: photoWithUrl },
    _count: { select: { likes: true, logs: true } },
    likes: viewerId
      ? { where: { userId: viewerId }, select: { userId: true } }
      : { where: { userId: "__none__" }, select: { userId: true } },
  } satisfies Prisma.ProjectSelect;
}

type ProjectRow = Prisma.ProjectGetPayload<{ select: ReturnType<typeof projectSelect> }>;

export interface ProjectDTO {
  id: string;
  owner: PublicUserDTO;
  title: string;
  description: string | null;
  craftType: string | null;
  yarn: string | null;
  hookSize: string | null;
  status: string;
  isPublic: boolean;
  coverUrl: string | null;
  likeCount: number;
  liked: boolean;
  logCount: number;
  createdAt: string;
  updatedAt: string;
}

export function serializeProject(
  project: ProjectRow,
  { viewerId }: { viewerId: string | undefined },
): ProjectDTO {
  return {
    id: project.id,
    owner: serializePublicUser(project.owner),
    title: project.title,
    description: project.description,
    craftType: project.craftType,
    yarn: project.yarn,
    hookSize: project.hookSize,
    status: project.status,
    isPublic: project.isPublic,
    coverUrl: project.cover ? publicUrl(project.cover.r2Key) : null,
    likeCount: project._count.likes,
    liked: viewerId ? project.likes.length > 0 : false,
    logCount: project._count.logs,
    createdAt: project.createdAt.toISOString(),
    updatedAt: project.updatedAt.toISOString(),
  };
}

// ---- ExternalPin ----------------------------------------------------------

export const externalPinSelect = {
  id: true,
  source: true,
  sourceUrl: true,
  imageUrl: true,
  title: true,
  createdAt: true,
} satisfies Prisma.ExternalPinSelect;

type ExternalPinRow = Prisma.ExternalPinGetPayload<{ select: typeof externalPinSelect }>;

export interface ExternalPinDTO {
  id: string;
  source: string;
  sourceUrl: string;
  imageUrl: string;
  title: string | null;
  createdAt: string;
}

export function serializeExternalPin(pin: ExternalPinRow): ExternalPinDTO {
  return {
    id: pin.id,
    source: pin.source,
    sourceUrl: pin.sourceUrl,
    imageUrl: pin.imageUrl,
    title: pin.title,
    createdAt: pin.createdAt.toISOString(),
  };
}

// ---- SearchResult ---------------------------------------------------------

export type SearchResultDTO =
  | { kind: "project"; project: ProjectDTO }
  | { kind: "pin"; pin: ExternalPinDTO };
