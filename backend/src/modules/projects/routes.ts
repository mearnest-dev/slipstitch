import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { ProjectStatus } from "@prisma/client";
import { prisma } from "../../lib/db.js";
import { badRequest, forbidden, notFound } from "../../lib/errors.js";
import { paginationQuery, buildPage } from "../../lib/pagination.js";
import {
  projectInclude,
  serializeProject,
  serializeProgressLog,
  serializePhoto,
  type ProjectWithRelations,
} from "./serialize.js";

// OWNED BY: feat/backend-projects worktree.
// Implements: CRUD /projects, /projects/:id, progress logs (/projects/:id/logs),
//   likes (/projects/:id/like)  (see docs/API.md). Mounted under /projects.

const projectCreateSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(5000).nullish(),
  craftType: z.string().max(100).nullish(),
  yarn: z.string().max(200).nullish(),
  hookSize: z.string().max(50).nullish(),
  status: z.nativeEnum(ProjectStatus).optional(),
  isPublic: z.boolean().optional(),
  coverPhotoId: z.string().nullish(),
});

const projectUpdateSchema = projectCreateSchema.partial();

const progressLogSchema = z.object({
  note: z.string().max(5000).nullish(),
  photoId: z.string().nullish(),
  rowCount: z.number().int().min(0).nullish(),
  hoursSpent: z.number().min(0).nullish(),
});

const idParams = z.object({ id: z.string().min(1) });

function parse<T extends z.ZodTypeAny>(schema: T, data: unknown): z.infer<T> {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw badRequest(result.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; "), "validation_error");
  }
  return result.data;
}

export const projectRoutes: FastifyPluginAsync = async (app) => {
  // GET /  — requester's own projects (paginated)
  app.get("/", { preHandler: app.authenticate }, async (req) => {
    const viewerId = req.userId!;
    const { cursor, limit } = parse(paginationQuery, req.query);
    const rows = await prisma.project.findMany({
      where: { ownerId: viewerId },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: projectInclude(viewerId),
    });
    const page = buildPage(rows as ProjectWithRelations[], limit);
    return {
      items: page.items.map((p) => serializeProject(p, { viewerId })),
      nextCursor: page.nextCursor,
    };
  });

  // POST /  — create a project
  app.post("/", { preHandler: app.authenticate }, async (req, reply) => {
    const viewerId = req.userId!;
    const body = parse(projectCreateSchema, req.body);

    if (body.coverPhotoId) {
      await assertOwnedPhoto(body.coverPhotoId, viewerId);
    }

    const created = await prisma.project.create({
      data: {
        ownerId: viewerId,
        title: body.title,
        description: body.description ?? null,
        craftType: body.craftType ?? null,
        yarn: body.yarn ?? null,
        hookSize: body.hookSize ?? null,
        ...(body.status !== undefined ? { status: body.status } : {}),
        ...(body.isPublic !== undefined ? { isPublic: body.isPublic } : {}),
        coverPhotoId: body.coverPhotoId ?? null,
      },
      include: projectInclude(viewerId),
    });
    reply.code(201);
    return serializeProject(created as ProjectWithRelations, { viewerId });
  });

  // GET /:id  — single project incl. logs + photos
  app.get("/:id", { preHandler: app.optionalAuth }, async (req) => {
    const viewerId = req.userId;
    const { id } = parse(idParams, req.params);
    const project = await prisma.project.findUnique({
      where: { id },
      include: {
        ...projectInclude(viewerId),
        logs: { orderBy: { createdAt: "desc" }, include: { photo: true } },
        photos: true,
      },
    });
    if (!project) throw notFound("Project not found");
    if (!project.isPublic && project.ownerId !== viewerId) {
      throw forbidden("This project is private");
    }
    return {
      ...serializeProject(project as ProjectWithRelations, { viewerId }),
      logs: project.logs.map(serializeProgressLog),
      photos: project.photos.map(serializePhoto),
    };
  });

  // PATCH /:id  — owner-only partial update
  app.patch("/:id", { preHandler: app.authenticate }, async (req) => {
    const viewerId = req.userId!;
    const { id } = parse(idParams, req.params);
    const body = parse(projectUpdateSchema, req.body);

    await assertOwnedProject(id, viewerId);

    if (body.coverPhotoId) {
      await assertOwnedPhoto(body.coverPhotoId, viewerId);
    }

    const updated = await prisma.project.update({
      where: { id },
      data: {
        ...(body.title !== undefined ? { title: body.title } : {}),
        ...(body.description !== undefined ? { description: body.description ?? null } : {}),
        ...(body.craftType !== undefined ? { craftType: body.craftType ?? null } : {}),
        ...(body.yarn !== undefined ? { yarn: body.yarn ?? null } : {}),
        ...(body.hookSize !== undefined ? { hookSize: body.hookSize ?? null } : {}),
        ...(body.status !== undefined ? { status: body.status } : {}),
        ...(body.isPublic !== undefined ? { isPublic: body.isPublic } : {}),
        ...(body.coverPhotoId !== undefined ? { coverPhotoId: body.coverPhotoId ?? null } : {}),
      },
      include: projectInclude(viewerId),
    });
    return serializeProject(updated as ProjectWithRelations, { viewerId });
  });

  // DELETE /:id  — owner-only
  app.delete("/:id", { preHandler: app.authenticate }, async (req, reply) => {
    const viewerId = req.userId!;
    const { id } = parse(idParams, req.params);
    await assertOwnedProject(id, viewerId);
    await prisma.project.delete({ where: { id } });
    reply.code(204);
    return null;
  });

  // POST /:id/logs  — owner-only, create a progress log
  app.post("/:id/logs", { preHandler: app.authenticate }, async (req, reply) => {
    const viewerId = req.userId!;
    const { id } = parse(idParams, req.params);
    const body = parse(progressLogSchema, req.body);
    await assertOwnedProject(id, viewerId);

    if (body.photoId) {
      await assertOwnedPhoto(body.photoId, viewerId);
    }

    const log = await prisma.progressLog.create({
      data: {
        projectId: id,
        note: body.note ?? null,
        photoId: body.photoId ?? null,
        rowCount: body.rowCount ?? null,
        hoursSpent: body.hoursSpent ?? null,
      },
      include: { photo: true },
    });
    reply.code(201);
    return serializeProgressLog(log);
  });

  // GET /:id/logs  — paginated, public unless private (owner only)
  app.get("/:id/logs", { preHandler: app.optionalAuth }, async (req) => {
    const viewerId = req.userId;
    const { id } = parse(idParams, req.params);
    const { cursor, limit } = parse(paginationQuery, req.query);

    const project = await prisma.project.findUnique({
      where: { id },
      select: { id: true, isPublic: true, ownerId: true },
    });
    if (!project) throw notFound("Project not found");
    if (!project.isPublic && project.ownerId !== viewerId) {
      throw forbidden("This project is private");
    }

    const rows = await prisma.progressLog.findMany({
      where: { projectId: id },
      orderBy: { createdAt: "desc" },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { photo: true },
    });
    const page = buildPage(rows, limit);
    return {
      items: page.items.map(serializeProgressLog),
      nextCursor: page.nextCursor,
    };
  });

  // POST /:id/like  — idempotent like
  app.post("/:id/like", { preHandler: app.authenticate }, async (req) => {
    const viewerId = req.userId!;
    const { id } = parse(idParams, req.params);

    const project = await prisma.project.findUnique({
      where: { id },
      select: { id: true, isPublic: true, ownerId: true },
    });
    if (!project) throw notFound("Project not found");
    if (!project.isPublic && project.ownerId !== viewerId) {
      throw forbidden("This project is private");
    }

    await prisma.like.upsert({
      where: { userId_projectId: { userId: viewerId, projectId: id } },
      create: { userId: viewerId, projectId: id },
      update: {},
    });
    const likeCount = await prisma.like.count({ where: { projectId: id } });
    return { liked: true, likeCount };
  });

  // DELETE /:id/like  — idempotent unlike
  app.delete("/:id/like", { preHandler: app.authenticate }, async (req) => {
    const viewerId = req.userId!;
    const { id } = parse(idParams, req.params);

    const exists = await prisma.project.findUnique({ where: { id }, select: { id: true } });
    if (!exists) throw notFound("Project not found");

    await prisma.like.deleteMany({ where: { userId: viewerId, projectId: id } });
    const likeCount = await prisma.like.count({ where: { projectId: id } });
    return { liked: false, likeCount };
  });
};

// --- helpers ---

async function assertOwnedProject(id: string, viewerId: string): Promise<void> {
  const project = await prisma.project.findUnique({
    where: { id },
    select: { ownerId: true },
  });
  if (!project) throw notFound("Project not found");
  if (project.ownerId !== viewerId) throw forbidden("You do not own this project");
}

async function assertOwnedPhoto(photoId: string, viewerId: string): Promise<void> {
  const photo = await prisma.photo.findUnique({
    where: { id: photoId },
    select: { ownerId: true },
  });
  if (!photo) throw badRequest("Referenced photo does not exist", "invalid_photo");
  if (photo.ownerId !== viewerId) throw forbidden("You do not own this photo");
}
