import type {
  Collection,
  CollectionItem,
  ExternalPin,
  Photo,
  Project,
  User,
} from "@prisma/client";
import { publicUrl } from "../../lib/r2.js";

// --- Collection ---------------------------------------------------------

export type CollectionForSerialize = Collection & {
  // cover photo loaded via coverPhotoId (Collection has no relation, so caller
  // attaches it explicitly), null when absent.
  coverPhoto?: Photo | null;
  _count?: { items: number };
};

export interface CollectionDTO {
  id: string;
  name: string;
  description: string | null;
  isPublic: boolean;
  coverUrl: string | null;
  itemCount: number;
  createdAt: Date;
}

export function serializeCollection(collection: CollectionForSerialize): CollectionDTO {
  return {
    id: collection.id,
    name: collection.name,
    description: collection.description,
    isPublic: collection.isPublic,
    coverUrl: collection.coverPhoto?.r2Key ? publicUrl(collection.coverPhoto.r2Key) : null,
    itemCount: collection._count?.items ?? 0,
    createdAt: collection.createdAt,
  };
}

// --- Compact project (local; do not import other modules) ---------------

type CompactProject = Project & {
  owner: Pick<User, "id" | "username" | "displayName">;
  cover?: Photo | null;
  _count?: { likes: number };
};

interface CompactProjectDTO {
  id: string;
  title: string;
  coverUrl: string | null;
  owner: { id: string; username: string; displayName: string };
  status: Project["status"];
  likeCount: number;
  createdAt: Date;
}

function serializeCompactProject(project: CompactProject): CompactProjectDTO {
  return {
    id: project.id,
    title: project.title,
    coverUrl: project.cover?.r2Key ? publicUrl(project.cover.r2Key) : null,
    owner: {
      id: project.owner.id,
      username: project.owner.username,
      displayName: project.owner.displayName,
    },
    status: project.status,
    likeCount: project._count?.likes ?? 0,
    createdAt: project.createdAt,
  };
}

// --- External pin -------------------------------------------------------

interface ExternalPinDTO {
  id: string;
  source: ExternalPin["source"];
  sourceUrl: string;
  imageUrl: string;
  title: string | null;
  createdAt: Date;
}

function serializeExternalPin(pin: ExternalPin): ExternalPinDTO {
  return {
    id: pin.id,
    source: pin.source,
    sourceUrl: pin.sourceUrl,
    imageUrl: pin.imageUrl,
    title: pin.title,
    createdAt: pin.createdAt,
  };
}

// --- Collection item ----------------------------------------------------

export type CollectionItemForSerialize = CollectionItem & {
  project?: CompactProject | null;
  externalPin?: ExternalPin | null;
};

export interface CollectionItemDTO {
  id: string;
  kind: "project" | "pin";
  project?: CompactProjectDTO;
  pin?: ExternalPinDTO;
  createdAt: Date;
}

export function serializeCollectionItem(item: CollectionItemForSerialize): CollectionItemDTO {
  const dto: CollectionItemDTO = {
    id: item.id,
    kind: item.projectId ? "project" : "pin",
    createdAt: item.createdAt,
  };
  if (item.project) dto.project = serializeCompactProject(item.project);
  if (item.externalPin) dto.pin = serializeExternalPin(item.externalPin);
  return dto;
}
