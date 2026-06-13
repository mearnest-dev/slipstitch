import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Prisma } from "@prisma/client";
import { prisma } from "../../lib/db.js";
import { badRequest, forbidden, notFound } from "../../lib/errors.js";
import { publicUrl } from "../../lib/r2.js";
import { buildPage, paginationQuery } from "../../lib/pagination.js";
import {
  serializeProject,
  serializePublicUser,
  serializeUser,
} from "./serialize.js";

// OWNED BY: feat/backend-auth worktree (users live with auth).
// Implements: GET/PATCH /me, GET /users/:id, POST/DELETE /users/:id/follow,
//   GET /users/:id/projects  (see docs/API.md). Mounts its own /me and /users paths.

const patchMeSchema = z.object({
  displayName: z.string().min(1).max(80).optional(),
  bio: z.string().max(500).nullable().optional(),
  avatarPhotoId: z.string().nullable().optional(),
  defaultCommentsEnabled: z.boolean().optional(),
  notificationsEnabled: z.boolean().optional(),
  socialLinks: z.array(z.string().trim().url().max(200)).max(5).optional(),
  activityVisible: z.boolean().optional(),
});

const activityQuery = z.object({
  before: z.coerce.date().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});

const onboardingSchema = z.object({
  interests: z.array(z.string().trim().min(1).max(40)).max(24).default([]),
  planningToMake: z.array(z.string().trim().min(1).max(120)).max(12).default([]),
});

const userSearchQuery = z.object({
  q: z.string().trim().min(1).max(100),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

function parse<T>(schema: z.ZodSchema<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    const first = result.error.issues[0];
    throw badRequest(first ? `${first.path.join(".")}: ${first.message}` : "Invalid request body");
  }
  return result.data;
}

const idParam = z.object({ id: z.string().min(1) });

export const userRoutes: FastifyPluginAsync = async (app) => {
  // GET /me
  app.get("/me", { preHandler: app.authenticate }, async (req) => {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
      include: { avatarPhoto: true },
    });
    if (!user) throw notFound("User not found", "user_not_found");
    return serializeUser(user);
  });

  // PATCH /me
  app.patch("/me", { preHandler: app.authenticate }, async (req) => {
    const body = parse(patchMeSchema, req.body);
    const data: Prisma.UserUpdateInput = {};
    if (body.displayName !== undefined) data.displayName = body.displayName;
    if (body.bio !== undefined) data.bio = body.bio;
    if (body.avatarPhotoId !== undefined) {
      data.avatarPhoto = body.avatarPhotoId
        ? { connect: { id: body.avatarPhotoId } }
        : { disconnect: true };
    }
    if (body.defaultCommentsEnabled !== undefined) {
      data.defaultCommentsEnabled = body.defaultCommentsEnabled;
    }
    if (body.notificationsEnabled !== undefined) {
      data.notificationsEnabled = body.notificationsEnabled;
    }
    if (body.socialLinks !== undefined) {
      data.socialLinks = body.socialLinks;
    }
    if (body.activityVisible !== undefined) {
      data.activityVisible = body.activityVisible;
    }

    const user = await prisma.user.update({
      where: { id: req.userId! },
      data,
      include: { avatarPhoto: true },
    });
    return serializeUser(user);
  });

  // POST /me/onboarding — store the signup survey. Saves interests, seeds the
  // journal with a `planning` project per planned make, and marks onboarding
  // complete (idempotent: re-running never duplicates planned projects).
  app.post("/me/onboarding", { preHandler: app.authenticate }, async (req) => {
    const viewerId = req.userId!;
    const body = parse(onboardingSchema, req.body);

    for (const title of body.planningToMake ?? []) {
      const existing = await prisma.project.findFirst({
        where: { ownerId: viewerId, title },
        select: { id: true },
      });
      if (!existing) {
        await prisma.project.create({
          data: { ownerId: viewerId, title, status: "planning" },
        });
      }
    }

    const user = await prisma.user.update({
      where: { id: viewerId },
      data: { interests: body.interests ?? [], onboardingCompleted: true },
      include: { avatarPhoto: true },
    });
    return serializeUser(user);
  });

  // DELETE /me — permanently delete the account. DB-level cascades remove the
  // user's projects, photos, comments, likes, follows, collections, and tokens.
  app.delete("/me", { preHandler: app.authenticate }, async (req, reply) => {
    await prisma.user.delete({ where: { id: req.userId! } });
    reply.code(204);
    return null;
  });

  // GET /users/search?q= — match username or display name (static segment, so
  // it never collides with /users/:id).
  app.get("/users/search", { preHandler: app.optionalAuth }, async (req) => {
    const { q, limit } = userSearchQuery.parse(req.query);
    const users = await prisma.user.findMany({
      where: {
        OR: [
          { username: { contains: q, mode: "insensitive" } },
          { displayName: { contains: q, mode: "insensitive" } },
        ],
      },
      orderBy: [{ followers: { _count: "desc" } }, { createdAt: "asc" }],
      take: limit,
      include: followListUserInclude(req.userId),
    });
    return { items: users.map(serializeFollowListUser) };
  });

  // GET /users/:id
  app.get("/users/:id", { preHandler: app.optionalAuth }, async (req) => {
    const { id } = parse(idParam, req.params);
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        avatarPhoto: true,
        _count: { select: { projects: true, followers: true, following: true } },
      },
    });
    if (!user) throw notFound("User not found", "user_not_found");

    const isFollowing = req.userId
      ? (await prisma.follow.findUnique({
          where: { followerId_followingId: { followerId: req.userId, followingId: id } },
        })) !== null
      : false;

    return serializePublicUser(user, {
      projectCount: user._count.projects,
      followerCount: user._count.followers,
      followingCount: user._count.following,
      isFollowing,
    });
  });

  // POST /users/:id/follow — idempotent.
  app.post("/users/:id/follow", { preHandler: app.authenticate }, async (req) => {
    const { id } = parse(idParam, req.params);
    if (id === req.userId!) throw badRequest("Cannot follow yourself", "cannot_follow_self");

    const target = await prisma.user.findUnique({ where: { id }, select: { id: true } });
    if (!target) throw notFound("User not found", "user_not_found");

    await prisma.follow.upsert({
      where: { followerId_followingId: { followerId: req.userId!, followingId: id } },
      create: { followerId: req.userId!, followingId: id },
      update: {},
    });
    return { following: true };
  });

  // DELETE /users/:id/follow — idempotent.
  app.delete("/users/:id/follow", { preHandler: app.authenticate }, async (req) => {
    const { id } = parse(idParam, req.params);
    await prisma.follow.deleteMany({
      where: { followerId: req.userId!, followingId: id },
    });
    return { following: false };
  });

  // GET /users/:id/followers — users who follow :id. Cursor is the previous
  // page's last user id (the listed side of the follow row).
  app.get("/users/:id/followers", { preHandler: app.optionalAuth }, async (req) => {
    const { id } = parse(idParam, req.params);
    const { cursor, limit } = paginationQuery.parse(req.query);
    await assertUserExists(id);

    const rows = await prisma.follow.findMany({
      where: { followingId: id },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor
        ? { cursor: { followerId_followingId: { followerId: cursor, followingId: id } }, skip: 1 }
        : {}),
      include: { follower: { include: followListUserInclude(req.userId) } },
    });

    const hasMore = rows.length > limit;
    const slice = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: slice.map((row) => serializeFollowListUser(row.follower)),
      nextCursor: hasMore ? slice[slice.length - 1]!.followerId : null,
    };
  });

  // GET /users/:id/following — users :id follows.
  app.get("/users/:id/following", { preHandler: app.optionalAuth }, async (req) => {
    const { id } = parse(idParam, req.params);
    const { cursor, limit } = paginationQuery.parse(req.query);
    await assertUserExists(id);

    const rows = await prisma.follow.findMany({
      where: { followerId: id },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor
        ? { cursor: { followerId_followingId: { followerId: id, followingId: cursor } }, skip: 1 }
        : {}),
      include: { following: { include: followListUserInclude(req.userId) } },
    });

    const hasMore = rows.length > limit;
    const slice = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: slice.map((row) => serializeFollowListUser(row.following)),
      nextCursor: hasMore ? slice[slice.length - 1]!.followingId : null,
    };
  });

  // GET /users/:id/activity — recent public actions (projects, progress,
  // comments, likes, follows) merged newest-first. Cursor is `before=<ISO>`.
  // 403 when the user has activity hidden (unless viewing yourself).
  app.get("/users/:id/activity", { preHandler: app.optionalAuth }, async (req) => {
    const { id } = parse(idParam, req.params);
    const { before, limit } = activityQuery.parse(req.query);

    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, activityVisible: true },
    });
    if (!user) throw notFound("User not found", "user_not_found");
    const isSelf = req.userId === id;
    if (!user.activityVisible && !isSelf) {
      throw forbidden("This user's activity is private", "activity_hidden");
    }

    const created = before ? { createdAt: { lt: before } } : {};
    const publicOnly = isSelf ? {} : { isPublic: true };
    const projectCard = {
      select: { id: true, title: true, cover: { select: { r2Key: true } } },
    } as const;

    const [projects, logs, comments, likes, follows] = await Promise.all([
      prisma.project.findMany({
        where: { ownerId: id, ...publicOnly, ...created },
        orderBy: { createdAt: "desc" },
        take: limit,
        select: { id: true, title: true, createdAt: true, cover: { select: { r2Key: true } } },
      }),
      prisma.progressLog.findMany({
        where: { project: { ownerId: id, ...publicOnly }, ...created },
        orderBy: { createdAt: "desc" },
        take: limit,
        select: { note: true, createdAt: true, project: projectCard },
      }),
      prisma.comment.findMany({
        where: { authorId: id, project: { isPublic: true }, ...created },
        orderBy: { createdAt: "desc" },
        take: limit,
        select: { body: true, createdAt: true, project: projectCard },
      }),
      prisma.like.findMany({
        where: { userId: id, project: { isPublic: true }, ...created },
        orderBy: { createdAt: "desc" },
        take: limit,
        select: { createdAt: true, project: projectCard },
      }),
      prisma.follow.findMany({
        where: { followerId: id, ...created },
        orderBy: { createdAt: "desc" },
        take: limit,
        select: {
          createdAt: true,
          following: {
            select: { id: true, username: true, displayName: true, avatarPhoto: { select: { r2Key: true } } },
          },
        },
      }),
    ]);

    type ProjectCard = { id: string; title: string; cover: { r2Key: string } | null };
    const card = (p: ProjectCard) => ({
      id: p.id,
      title: p.title,
      coverUrl: p.cover ? publicUrl(p.cover.r2Key) : null,
    });

    const events = [
      ...projects.map((p) => ({
        type: "project" as const, createdAt: p.createdAt, project: card(p),
      })),
      ...logs.map((l) => ({
        type: "progress" as const, createdAt: l.createdAt, project: card(l.project), body: l.note,
      })),
      ...comments.map((c) => ({
        type: "comment" as const, createdAt: c.createdAt, project: card(c.project), body: c.body,
      })),
      ...likes.map((l) => ({
        type: "like" as const, createdAt: l.createdAt, project: card(l.project),
      })),
      ...follows.map((f) => ({
        type: "follow" as const,
        createdAt: f.createdAt,
        user: {
          id: f.following.id,
          username: f.following.username,
          displayName: f.following.displayName,
          avatarUrl: f.following.avatarPhoto ? publicUrl(f.following.avatarPhoto.r2Key) : null,
        },
      })),
    ].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    const page = events.slice(0, limit);
    const hasMore = events.length > limit;
    return {
      items: page.map((e) => ({ ...e, createdAt: e.createdAt.toISOString() })),
      nextCursor: hasMore && page.length > 0 ? page[page.length - 1]!.createdAt.toISOString() : null,
    };
  });

  // GET /users/:id/projects — paginated; public only unless requester is the owner.
  app.get("/users/:id/projects", { preHandler: app.optionalAuth }, async (req) => {
    const { id } = parse(idParam, req.params);
    const { cursor, limit } = paginationQuery.parse(req.query);

    const isSelf = req.userId === id;
    const where: Prisma.ProjectWhereInput = {
      ownerId: id,
      ...(isSelf ? {} : { isPublic: true }),
    };

    const rows = await prisma.project.findMany({
      where,
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        owner: { include: { avatarPhoto: true } },
        cover: true,
        _count: { select: { likes: true, logs: true, comments: true } },
        likes: req.userId
          ? { where: { userId: req.userId }, select: { userId: true } }
          : { where: { userId: "" }, select: { userId: true } },
      },
    });

    const page = buildPage(rows, limit);

    // Owner is the same user for every row; build their PublicUser once.
    const ownerCounts = await ownerPublicCounts(id, req.userId);

    const items = page.items.map((project) => {
      const owner = serializePublicUser(project.owner, ownerCounts);
      const liked = req.userId ? project.likes.length > 0 : false;
      return serializeProject(project, owner, { liked });
    });

    return { items, nextCursor: page.nextCursor };
  });
};

async function assertUserExists(id: string): Promise<void> {
  const user = await prisma.user.findUnique({ where: { id }, select: { id: true } });
  if (!user) throw notFound("User not found", "user_not_found");
}

/** Include for a user row in a follower/following/search list: avatar, counts,
 * and the viewer's own follow row (if any) so `isFollowing` is cheap. */
function followListUserInclude(viewerId: string | undefined) {
  return {
    avatarPhoto: true,
    _count: { select: { projects: true, followers: true, following: true } },
    followers: viewerId
      ? { where: { followerId: viewerId }, select: { followerId: true } }
      : { where: { followerId: "" }, select: { followerId: true } },
  } satisfies Prisma.UserInclude;
}

type FollowListUser = Prisma.UserGetPayload<{
  include: ReturnType<typeof followListUserInclude>;
}>;

function serializeFollowListUser(user: FollowListUser) {
  return serializePublicUser(user, {
    projectCount: user._count.projects,
    followerCount: user._count.followers,
    followingCount: user._count.following,
    isFollowing: user.followers.length > 0,
  });
}

async function ownerPublicCounts(ownerId: string, viewerId: string | undefined) {
  const [projectCount, followerCount, followingCount, follow] = await Promise.all([
    prisma.project.count({ where: { ownerId } }),
    prisma.follow.count({ where: { followingId: ownerId } }),
    prisma.follow.count({ where: { followerId: ownerId } }),
    viewerId
      ? prisma.follow.findUnique({
          where: { followerId_followingId: { followerId: viewerId, followingId: ownerId } },
        })
      : Promise.resolve(null),
  ]);
  return { projectCount, followerCount, followingCount, isFollowing: follow !== null };
}
