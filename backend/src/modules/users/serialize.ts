import type { Photo, Project, ProjectStatus, User } from "@prisma/client";
import { publicUrl } from "../../lib/r2.js";

// DTO shapes mirror docs/API.md.

export interface UserDTO {
  id: string;
  username: string;
  displayName: string;
  email: string | null;
  bio: string | null;
  avatarUrl: string | null;
  defaultCommentsEnabled: boolean;
  notificationsEnabled: boolean;
  createdAt: string;
}

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

export interface ProjectDTO {
  id: string;
  owner: PublicUserDTO;
  title: string;
  description: string | null;
  craftType: string | null;
  yarn: string | null;
  yarnWeight: string | null;
  hookSize: string | null;
  status: ProjectStatus;
  isPublic: boolean;
  commentsEnabled: boolean;
  coverUrl: string | null;
  likeCount: number;
  liked: boolean;
  logCount: number;
  commentCount: number;
  createdAt: string;
  updatedAt: string;
}

/** Resolve the public CDN URL for an (optional) uploaded photo. */
export function photoUrl(photo: Photo | null | undefined): string | null {
  if (!photo) return null;
  return publicUrl(photo.r2Key);
}

/** Self-view DTO (includes email). */
export function serializeUser(user: User & { avatarPhoto?: Photo | null }): UserDTO {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    email: user.email,
    bio: user.bio,
    avatarUrl: photoUrl(user.avatarPhoto),
    defaultCommentsEnabled: user.defaultCommentsEnabled,
    notificationsEnabled: user.notificationsEnabled,
    createdAt: user.createdAt.toISOString(),
  };
}

export interface PublicUserCounts {
  projectCount: number;
  followerCount: number;
  followingCount: number;
  isFollowing: boolean;
}

export function serializePublicUser(
  user: User & { avatarPhoto?: Photo | null },
  counts: PublicUserCounts,
): PublicUserDTO {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    bio: user.bio,
    avatarUrl: photoUrl(user.avatarPhoto),
    projectCount: counts.projectCount,
    followerCount: counts.followerCount,
    followingCount: counts.followingCount,
    isFollowing: counts.isFollowing,
  };
}

export type ProjectWithRelations = Project & {
  owner: User & { avatarPhoto?: Photo | null };
  cover?: Photo | null;
  _count?: { likes?: number; logs?: number; comments?: number };
};

export function serializeProject(
  project: ProjectWithRelations,
  owner: PublicUserDTO,
  opts: { liked: boolean },
): ProjectDTO {
  return {
    id: project.id,
    owner,
    title: project.title,
    description: project.description,
    craftType: project.craftType,
    yarn: project.yarn,
    yarnWeight: project.yarnWeight,
    hookSize: project.hookSize,
    status: project.status,
    isPublic: project.isPublic,
    commentsEnabled: project.commentsEnabled,
    coverUrl: photoUrl(project.cover),
    likeCount: project._count?.likes ?? 0,
    liked: opts.liked,
    logCount: project._count?.logs ?? 0,
    commentCount: project._count?.comments ?? 0,
    createdAt: project.createdAt.toISOString(),
    updatedAt: project.updatedAt.toISOString(),
  };
}
