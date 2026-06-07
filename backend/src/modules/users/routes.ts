import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Prisma } from "@prisma/client";
import { prisma } from "../../lib/db.js";
import { badRequest, notFound } from "../../lib/errors.js";
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

    const user = await prisma.user.update({
      where: { id: req.userId! },
      data,
      include: { avatarPhoto: true },
    });
    return serializeUser(user);
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
        _count: { select: { likes: true, logs: true } },
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
