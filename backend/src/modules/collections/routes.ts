import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/db.js";
import { badRequest, conflict, forbidden, notFound } from "../../lib/errors.js";
import {
  serializeCollection,
  serializeCollectionItem,
  type CollectionForSerialize,
} from "./serialize.js";

// OWNED BY: feat/backend-collections worktree.
// CRUD /collections, /collections/:id, items (projectId OR externalPinId).
// Mounted under /collections. See docs/API.md.

const createSchema = z.object({
  name: z.string().min(1).max(120),
  description: z.string().max(2000).optional(),
  isPublic: z.boolean().optional(),
});

const updateSchema = z
  .object({
    name: z.string().min(1).max(120).optional(),
    description: z.string().max(2000).nullable().optional(),
    isPublic: z.boolean().optional(),
  })
  .refine((b) => Object.keys(b).length > 0, { message: "No fields to update" });

const addItemSchema = z
  .union([
    z.object({ projectId: z.string().min(1) }),
    z.object({ externalPinId: z.string().min(1) }),
  ])
  .refine(
    (b) =>
      ("projectId" in b && !("externalPinId" in b)) ||
      ("externalPinId" in b && !("projectId" in b)),
    { message: "Provide exactly one of projectId or externalPinId" },
  );

const idParams = z.object({ id: z.string().min(1) });
const itemParams = z.object({ id: z.string().min(1), itemId: z.string().min(1) });

// Compact project include used inside collection items.
const compactProjectInclude = {
  owner: { select: { id: true, username: true, displayName: true } },
  cover: true,
  _count: { select: { likes: true } },
} satisfies Prisma.ProjectInclude;

const itemInclude = {
  project: { include: compactProjectInclude },
  externalPin: true,
} satisfies Prisma.CollectionItemInclude;

/** Attach the cover Photo (Collection has only coverPhotoId, no relation). */
async function withCoverPhoto<T extends { coverPhotoId: string | null }>(
  collection: T,
): Promise<T & CollectionForSerialize> {
  const coverPhoto = collection.coverPhotoId
    ? await prisma.photo.findUnique({ where: { id: collection.coverPhotoId } })
    : null;
  return { ...collection, coverPhoto } as T & CollectionForSerialize;
}

export const collectionRoutes: FastifyPluginAsync = async (app) => {
  // GET / — the requester's collections.
  app.get("/", { preHandler: app.authenticate }, async (req) => {
    const userId = req.userId!;
    const collections = await prisma.collection.findMany({
      where: { ownerId: userId },
      orderBy: { createdAt: "desc" },
      include: { _count: { select: { items: true } } },
    });
    const withCovers = await Promise.all(collections.map((c) => withCoverPhoto(c)));
    return withCovers.map(serializeCollection);
  });

  // POST / — create a collection.
  app.post("/", { preHandler: app.authenticate }, async (req, reply) => {
    const userId = req.userId!;
    const body = createSchema.parse(req.body);
    const created = await prisma.collection.create({
      data: {
        ownerId: userId,
        name: body.name,
        description: body.description,
        isPublic: body.isPublic ?? false,
      },
      include: { _count: { select: { items: true } } },
    });
    reply.code(201);
    return serializeCollection(await withCoverPhoto(created));
  });

  // GET /:id — collection with items. 404/403 for private non-owner.
  app.get("/:id", { preHandler: app.optionalAuth }, async (req) => {
    const { id } = idParams.parse(req.params);
    const collection = await prisma.collection.findUnique({
      where: { id },
      include: {
        _count: { select: { items: true } },
        items: { orderBy: { createdAt: "desc" }, include: itemInclude },
      },
    });
    if (!collection) throw notFound("Collection not found");
    if (!collection.isPublic && collection.ownerId !== req.userId) {
      throw forbidden("This collection is private");
    }
    const serialized = serializeCollection(await withCoverPhoto(collection));
    return {
      ...serialized,
      items: collection.items.map(serializeCollectionItem),
    };
  });

  // PATCH /:id — owner only.
  app.patch("/:id", { preHandler: app.authenticate }, async (req) => {
    const userId = req.userId!;
    const { id } = idParams.parse(req.params);
    const body = updateSchema.parse(req.body);

    const existing = await prisma.collection.findUnique({ where: { id } });
    if (!existing) throw notFound("Collection not found");
    if (existing.ownerId !== userId) throw forbidden("Not your collection");

    const updated = await prisma.collection.update({
      where: { id },
      data: {
        name: body.name,
        description: body.description,
        isPublic: body.isPublic,
      },
      include: { _count: { select: { items: true } } },
    });
    return serializeCollection(await withCoverPhoto(updated));
  });

  // DELETE /:id — owner only.
  app.delete("/:id", { preHandler: app.authenticate }, async (req, reply) => {
    const userId = req.userId!;
    const { id } = idParams.parse(req.params);

    const existing = await prisma.collection.findUnique({ where: { id } });
    if (!existing) throw notFound("Collection not found");
    if (existing.ownerId !== userId) throw forbidden("Not your collection");

    await prisma.collection.delete({ where: { id } });
    reply.code(204);
    return null;
  });

  // POST /:id/items — add a project or external pin. Owner only.
  app.post("/:id/items", { preHandler: app.authenticate }, async (req, reply) => {
    const userId = req.userId!;
    const { id } = idParams.parse(req.params);
    const body = addItemSchema.parse(req.body);

    const collection = await prisma.collection.findUnique({ where: { id } });
    if (!collection) throw notFound("Collection not found");
    if (collection.ownerId !== userId) throw forbidden("Not your collection");

    if ("projectId" in body) {
      const project = await prisma.project.findUnique({ where: { id: body.projectId } });
      if (!project) throw badRequest("Project not found", "project_not_found");
      const existing = await prisma.collectionItem.findUnique({
        where: { collectionId_projectId: { collectionId: id, projectId: body.projectId } },
      });
      if (existing) throw conflict("Project already in collection");
    } else {
      const pin = await prisma.externalPin.findUnique({ where: { id: body.externalPinId } });
      if (!pin) throw badRequest("External pin not found", "pin_not_found");
      const existing = await prisma.collectionItem.findUnique({
        where: {
          collectionId_externalPinId: { collectionId: id, externalPinId: body.externalPinId },
        },
      });
      if (existing) throw conflict("Pin already in collection");
    }

    const item = await prisma.collectionItem.create({
      data: {
        collectionId: id,
        projectId: "projectId" in body ? body.projectId : null,
        externalPinId: "externalPinId" in body ? body.externalPinId : null,
      },
      include: itemInclude,
    });
    reply.code(201);
    return serializeCollectionItem(item);
  });

  // DELETE /:id/items/:itemId — owner only.
  app.delete("/:id/items/:itemId", { preHandler: app.authenticate }, async (req, reply) => {
    const userId = req.userId!;
    const { id, itemId } = itemParams.parse(req.params);

    const collection = await prisma.collection.findUnique({ where: { id } });
    if (!collection) throw notFound("Collection not found");
    if (collection.ownerId !== userId) throw forbidden("Not your collection");

    const item = await prisma.collectionItem.findUnique({ where: { id: itemId } });
    if (!item || item.collectionId !== id) throw notFound("Item not found");

    await prisma.collectionItem.delete({ where: { id: itemId } });
    reply.code(204);
    return null;
  });
};
