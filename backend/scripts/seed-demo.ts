/**
 * Seed believable demo content for the App Store listing.
 *
 * Creates 9 maker personas (all with emails @seed.slipstitch.app and the
 * password "SlipstitchDemo1!" so you can sign in as any of them for
 * screenshots), their projects with CC0 photos (Openverse; see
 * seed-images/sources.json for provenance), progress logs, comments, likes,
 * follows, and public collections. Timestamps are staggered over ~6 weeks so
 * the feed looks lived-in.
 *
 * Usage:
 *   npx tsx scripts/seed-demo.ts            # seeds (aborts if already seeded)
 *   npx tsx scripts/seed-demo.ts --reset    # deletes seed users first, then seeds
 *
 * Run against production with Railway-injected env:
 *   railway run -- npx tsx scripts/seed-demo.ts
 */
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import argon2 from "argon2";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { prisma } from "../src/lib/db.js";
import { env } from "../src/config/env.js";

const SEED_DOMAIN = "seed.slipstitch.app";
const DEMO_PASSWORD = "SlipstitchDemo1!";
const IMAGE_DIR = join(dirname(fileURLToPath(import.meta.url)), "seed-images", "resized");

interface ManifestImage {
  file: string;
  width: number;
  height: number;
}
const manifest: ManifestImage[] = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), "seed-images", "manifest.json"), "utf8"),
);
const imageByFile = new Map(manifest.map((m) => [m.file, m]));

const s3 = new S3Client({
  region: "auto",
  endpoint: env.R2_ENDPOINT,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID ?? "",
    secretAccessKey: env.R2_SECRET_ACCESS_KEY ?? "",
  },
});

// Days-ago helper for backdating.
const daysAgo = (d: number, hourJitter = 0) =>
  new Date(Date.now() - d * 86_400_000 + hourJitter * 3_600_000);

let uploadCount = 0;
async function uploadImage(file: string): Promise<{ key: string; width: number; height: number }> {
  const meta = imageByFile.get(file);
  if (!meta) throw new Error(`No manifest entry for ${file}`);
  const key = `seed/${file.replace(".jpg", "")}-${Math.random().toString(36).slice(2, 8)}.jpg`;
  await s3.send(
    new PutObjectCommand({
      Bucket: env.R2_BUCKET,
      Key: key,
      Body: readFileSync(join(IMAGE_DIR, file)),
      ContentType: "image/jpeg",
    }),
  );
  uploadCount++;
  return { key, width: meta.width, height: meta.height };
}

async function createPhoto(ownerId: string, file: string, createdAt: Date) {
  const { key, width, height } = await uploadImage(file);
  return prisma.photo.create({
    data: { ownerId, r2Key: key, width, height, uploaded: true, createdAt },
  });
}

// ---------------------------------------------------------------------------
// Personas
// ---------------------------------------------------------------------------

interface PersonaSpec {
  username: string;
  displayName: string;
  bio: string;
  interests: string[];
  avatar?: string; // manifest file
  joinedDaysAgo: number;
}

const PERSONAS: PersonaSpec[] = [
  { username: "mira_makes", displayName: "Mira Chen", bio: "Amigurumi addict 🧸 If it's small and round, I will crochet it. Probably twice.", interests: ["amigurumi", "toys"], avatar: "img08.jpg", joinedDaysAgo: 48 },
  { username: "theloopylama", displayName: "Dana Whitfield", bio: "Making a tiny zoo, one skein at a time. Safety eyes hoarder.", interests: ["amigurumi", "toys", "baby items"], avatar: "img06.jpg", joinedDaysAgo: 45 },
  { username: "grannysquaregwen", displayName: "Gwen Alvarez", bio: "Granny squares are a lifestyle. Ask me about my hexagon phase.", interests: ["granny squares", "blankets & throws"], avatar: "img11.jpg", joinedDaysAgo: 44 },
  { username: "cozycorner_kate", displayName: "Kate O'Brien", bio: "Blankets big enough to hide under. Tea, true crime podcasts, treble crochet.", interests: ["blankets & throws", "home decor"], avatar: "img15.jpg", joinedDaysAgo: 42 },
  { username: "blanketstateofmind", displayName: "Amara Diallo", bio: "Colorwork enthusiast. Currently buried under a ripple blanket WIP.", interests: ["blankets & throws", "granny squares"], avatar: "img17.jpg", joinedDaysAgo: 40 },
  { username: "hookandhome", displayName: "Priya Patel", bio: "Crochet for the home — baskets, cozies, and anything that holds other things.", interests: ["home decor", "kitchen & coasters"], avatar: "img00.jpg", joinedDaysAgo: 38 },
  { username: "yarnhoarder_jo", displayName: "Jo Lindqvist", bio: "My stash has a stash. Recovering (not really) yarn collector from Malmö.", interests: ["wearables", "shawls & wraps"], avatar: "img22.jpg", joinedDaysAgo: 35 },
  { username: "stitchwitch_sam", displayName: "Sam Rivera", bio: "Fiber artist. Tapestry crochet, wall hangings, and chaotic color choices.", interests: ["home decor", "wearables"], avatar: "img01.jpg", joinedDaysAgo: 33 },
  { username: "fiberfiend_max", displayName: "Max Kowalski", bio: "Brand new hooker (of yarn). Learning in public — be nice to my tension.", interests: ["granny squares", "hats & beanies"], avatar: "img21.jpg", joinedDaysAgo: 12 },
];

// ---------------------------------------------------------------------------
// Projects (per persona username)
// ---------------------------------------------------------------------------

interface LogSpec {
  note: string;
  rowCount?: number;
  hoursSpent?: number;
  photo?: string;
  daysAfterProject: number;
}

interface ProjectSpec {
  owner: string;
  title: string;
  description: string;
  craftType: string;
  yarn?: string;
  yarnWeight?: string;
  hookSize?: string;
  status: "planning" | "inProgress" | "finished" | "frogged";
  cover?: string;
  createdDaysAgo: number;
  logs: LogSpec[];
}

const PROJECTS: ProjectSpec[] = [
  {
    owner: "mira_makes", title: "Mouse in a sweater", craftType: "amigurumi",
    description: "Tiny mouse, tinier sweater. Pattern improvised after the third frogging. The ears took four attempts but look at him.",
    yarn: "Scheepjes Catona", yarnWeight: "Fine (2)", hookSize: "2.5 mm", status: "finished",
    cover: "img06.jpg", createdDaysAgo: 40,
    logs: [
      { note: "Body and head done. He looks like a potato with ears and I love him already.", rowCount: 32, hoursSpent: 3, daysAfterProject: 2 },
      { note: "Sweater finished! Stripes line up on the first try, which has never happened in recorded history.", hoursSpent: 2.5, daysAfterProject: 6 },
      { note: "Assembled and stuffed. Officially a mouse. 🐭", hoursSpent: 1, daysAfterProject: 9 },
    ],
  },
  {
    owner: "mira_makes", title: "Cactus that never dies", craftType: "amigurumi",
    description: "For my friend who has killed every real plant she's ever owned. This one is immortal and slightly menacing.",
    yarn: "Paintbox Cotton DK", yarnWeight: "Light (3)", hookSize: "3 mm", status: "finished",
    cover: "img08.jpg", createdDaysAgo: 22,
    logs: [
      { note: "Spikes are just reverse single crochet and honestly? Transformative.", rowCount: 18, hoursSpent: 2, daysAfterProject: 1 },
      { note: "Potted. She can't kill this one. Mission accomplished. 🌵", hoursSpent: 1.5, daysAfterProject: 4 },
    ],
  },
  {
    owner: "theloopylama", title: "Amigurumi pals", craftType: "amigurumi",
    description: "A whole little crew for my nephew's birthday. Started with one bear. It escalated.",
    yarn: "YarnArt Jeans", yarnWeight: "Light (3)", hookSize: "2.5 mm", status: "inProgress",
    cover: "img07.jpg", createdDaysAgo: 30,
    logs: [
      { note: "Bear #1 complete. Nephew has already named him 'Bread'. No further questions.", hoursSpent: 4, daysAfterProject: 3 },
      { note: "Bunny done, working on the frog. The frog has opinions.", rowCount: 45, hoursSpent: 3.5, daysAfterProject: 12 },
    ],
  },
  {
    owner: "grannysquaregwen", title: "Sunset granny square", craftType: "granny square",
    description: "Pink → magenta → orange fade. One giant continuous granny square, because joining 96 small ones is a punishment I've already served.",
    yarn: "Stylecraft Special DK", yarnWeight: "Light (3)", hookSize: "4 mm", status: "finished",
    cover: "img11.jpg", createdDaysAgo: 36,
    logs: [
      { note: "Round 24. The fade is FADING and it's everything I hoped.", rowCount: 24, hoursSpent: 5, daysAfterProject: 4 },
      { note: "Blocked and done. Immediate sofa upgrade.", hoursSpent: 2, daysAfterProject: 11 },
    ],
  },
  {
    owner: "grannysquaregwen", title: "Flower garden squares", craftType: "granny square",
    description: "Flower-centre squares for a spring throw. One square a day keeps the doom scroll away.",
    yarn: "Drops Safran", yarnWeight: "Fine (2)", hookSize: "3.5 mm", status: "inProgress",
    cover: "img12.jpg", createdDaysAgo: 18,
    logs: [
      { note: "14 squares in. The round flower centres are so satisfying to make.", hoursSpent: 6, daysAfterProject: 7, photo: "img12.jpg" },
    ],
  },
  {
    owner: "cozycorner_kate", title: "Granny stripe blanket", craftType: "blanket",
    description: "Classic granny stripe in every leftover DK I own. Stash-busting is self-care.",
    yarn: "Assorted DK stash", yarnWeight: "Light (3)", hookSize: "4.5 mm", status: "finished",
    cover: "img10.jpg", createdDaysAgo: 38,
    logs: [
      { note: "30 stripes deep. The color order is 100% vibes and it's working.", rowCount: 30, hoursSpent: 8, daysAfterProject: 6 },
      { note: "Border done — one round of crab stitch to finish. So warm. So heavy. Perfect.", hoursSpent: 3, daysAfterProject: 16 },
    ],
  },
  {
    owner: "cozycorner_kate", title: "Berry patch blanket", craftType: "blanket",
    description: "Blues, pinks, purples and white — like a berry smoothie someone spilled on a cloud. King size because I have no self-preservation instinct.",
    yarn: "Caron Simply Soft", yarnWeight: "Medium (4)", hookSize: "5 mm", status: "inProgress",
    cover: "img15.jpg", createdDaysAgo: 20,
    logs: [
      { note: "A third of the way. My wrist has filed a formal complaint.", rowCount: 58, hoursSpent: 12, daysAfterProject: 8 },
      { note: "Halfway! Laid it on the bed to check the size and the cat has claimed it. Project paused pending negotiations.", rowCount: 30, hoursSpent: 7, daysAfterProject: 15, photo: "img15.jpg" },
    ],
  },
  {
    owner: "blanketstateofmind", title: "Seaside throw", craftType: "blanket",
    description: "Stripes pulled from a photo of the Brittany coast. Wave stitch, obviously.",
    yarn: "Scheepjes Colour Crafter", yarnWeight: "Light (3)", hookSize: "4 mm", status: "finished",
    cover: "img17.jpg", createdDaysAgo: 32,
    logs: [
      { note: "Wave stitch repeat memorized. I can finally watch TV again while working on it.", rowCount: 40, hoursSpent: 9, daysAfterProject: 5 },
      { note: "Done and blocked! Gifting this one is going to hurt.", hoursSpent: 2, daysAfterProject: 14 },
    ],
  },
  {
    owner: "blanketstateofmind", title: "Harvest ripple blanket", craftType: "blanket",
    description: "Autumn ripple in rust, mustard and cream. Yes I started an autumn blanket in spring. Planning ahead is a virtue.",
    yarn: "Paintbox Simply Aran", yarnWeight: "Medium (4)", hookSize: "5 mm", status: "inProgress",
    cover: "img18.jpg", createdDaysAgo: 14,
    logs: [
      { note: "Foundation chain of 274. Counted it three times. Lit a candle. Began.", rowCount: 12, hoursSpent: 4, daysAfterProject: 2 },
    ],
  },
  {
    owner: "hookandhome", title: "Nesting baskets", craftType: "home decor",
    description: "Three sizes of sturdy rope-core baskets. The big one holds yarn. The medium one holds yarn. The small one... also yarn.",
    yarn: "Hoooked Zpagetti + cotton cord", yarnWeight: "Jumbo (7)", hookSize: "10 mm", status: "finished",
    cover: "img04.jpg", createdDaysAgo: 34,
    logs: [
      { note: "Base of the big basket done. Working over rope core makes them stand up SO well.", rowCount: 14, hoursSpent: 2, daysAfterProject: 2, photo: "img05.jpg" },
      { note: "All three done. They nest. I am at peace.", hoursSpent: 5, daysAfterProject: 9 },
    ],
  },
  {
    owner: "hookandhome", title: "Tiny mug cozies", craftType: "kitchen",
    description: "Espresso cup cozies with little buttons. Completely unnecessary. Completely essential.",
    yarn: "Rico Creative Cotton", yarnWeight: "Medium (4)", hookSize: "4 mm", status: "finished",
    cover: "img00.jpg", createdDaysAgo: 26,
    logs: [
      { note: "Made four in one evening. Instant gratification crochet is real.", hoursSpent: 3, daysAfterProject: 1, photo: "img03.jpg" },
    ],
  },
  {
    owner: "yarnhoarder_jo", title: "The great stash sort", craftType: "stash",
    description: "Not technically a make, but cataloguing the entire stash by weight and color before I'm allowed to start the next sweater. Documenting for accountability.",
    yarn: "All of it. Literally all of it.", status: "inProgress",
    cover: "img23.jpg", createdDaysAgo: 16,
    logs: [
      { note: "Shelf one: sorted by weight. Found three identical skeins of teal DK bought on three separate occasions. No regrets.", hoursSpent: 2, daysAfterProject: 1, photo: "img20.jpg" },
      { note: "The hand-dyed section is now in rainbow order and I keep going back to look at it.", hoursSpent: 1.5, daysAfterProject: 5, photo: "img22.jpg" },
      { note: "Update: bought more yarn 'to complete the gradient'. The sort continues.", hoursSpent: 1, daysAfterProject: 8, photo: "img21.jpg" },
    ],
  },
  {
    owner: "stitchwitch_sam", title: "Watercolor wall hanging", craftType: "wall hanging",
    description: "Tapestry crochet panel based on one of my old watercolor sketches. Carrying four colors at once builds character.",
    yarn: "Scheepjes Whirl", yarnWeight: "Fine (2)", hookSize: "3 mm", status: "finished",
    cover: "img01.jpg", createdDaysAgo: 28,
    logs: [
      { note: "Chart row 40/96. My floats are finally laying flat. Growth.", rowCount: 40, hoursSpent: 10, daysAfterProject: 6, photo: "img02.jpg" },
      { note: "Mounted on driftwood and hung. Gallery wall complete. 🎨", hoursSpent: 2, daysAfterProject: 13 },
    ],
  },
  {
    owner: "fiberfiend_max", title: "My first granny square", craftType: "granny square",
    description: "Everyone says start here, so here I am. Watched the tutorial six times. Chain four, join... wish me luck.",
    yarn: "Big Twist Value", yarnWeight: "Medium (4)", hookSize: "5 mm", status: "inProgress",
    createdDaysAgo: 8,
    logs: [
      { note: "Round one looks like a square if you squint. Calling that a win.", hoursSpent: 1.5, daysAfterProject: 1 },
      { note: "Round three!! It's actually square now. I get it. I finally get the hype.", hoursSpent: 1, daysAfterProject: 4 },
    ],
  },
  {
    owner: "fiberfiend_max", title: "Chunky beanie (someday)", craftType: "hat",
    description: "The goal that got me into this. Once I can make a square, the beanie is next.",
    yarnWeight: "Bulky (5)", status: "planning", createdDaysAgo: 8, logs: [],
  },
];

// ---------------------------------------------------------------------------
// Social graph
// ---------------------------------------------------------------------------

// follower -> following
const FOLLOWS: Array<[string, string]> = [
  ["theloopylama", "mira_makes"], ["fiberfiend_max", "mira_makes"], ["grannysquaregwen", "mira_makes"],
  ["cozycorner_kate", "mira_makes"], ["yarnhoarder_jo", "mira_makes"], ["stitchwitch_sam", "mira_makes"],
  ["mira_makes", "theloopylama"], ["fiberfiend_max", "theloopylama"],
  ["cozycorner_kate", "grannysquaregwen"], ["blanketstateofmind", "grannysquaregwen"],
  ["fiberfiend_max", "grannysquaregwen"], ["mira_makes", "grannysquaregwen"], ["hookandhome", "grannysquaregwen"],
  ["grannysquaregwen", "cozycorner_kate"], ["blanketstateofmind", "cozycorner_kate"], ["yarnhoarder_jo", "cozycorner_kate"],
  ["cozycorner_kate", "blanketstateofmind"], ["grannysquaregwen", "blanketstateofmind"], ["fiberfiend_max", "blanketstateofmind"],
  ["yarnhoarder_jo", "hookandhome"], ["stitchwitch_sam", "hookandhome"], ["mira_makes", "hookandhome"],
  ["hookandhome", "yarnhoarder_jo"], ["stitchwitch_sam", "yarnhoarder_jo"],
  ["yarnhoarder_jo", "stitchwitch_sam"], ["blanketstateofmind", "stitchwitch_sam"], ["hookandhome", "stitchwitch_sam"],
  ["mira_makes", "fiberfiend_max"], ["grannysquaregwen", "fiberfiend_max"],
];

// project title -> [commenter, body, daysAfterProject]
const COMMENTS: Array<[string, string, string, number]> = [
  ["Mouse in a sweater", "theloopylama", "The SWEATER. The stripes lining up at the seam is incredibly satisfying.", 10],
  ["Mouse in a sweater", "grannysquaregwen", "I don't even make amigurumi and I need this mouse.", 11],
  ["Mouse in a sweater", "fiberfiend_max", "How do you get the stitches so even at this size?? Asking for my lumpy future projects.", 12],
  ["Mouse in a sweater", "cozycorner_kate", "Bread the bear has competition for best-dressed.", 13],
  ["Cactus that never dies", "yarnhoarder_jo", "The reverse single crochet spikes are genius. Stealing this immediately.", 5],
  ["Cactus that never dies", "theloopylama", "Menacing AND immortal. The perfect houseplant.", 6],
  ["Amigurumi pals", "mira_makes", "'The frog has opinions' — they always do. Always.", 13],
  ["Amigurumi pals", "fiberfiend_max", "Bread!! Incredible name, incredible bear.", 14],
  ["Sunset granny square", "cozycorner_kate", "This fade is unreal. Did you plan the transition rounds or wing it?", 12],
  ["Sunset granny square", "blanketstateofmind", "One giant square was the right call. The drape must be gorgeous.", 13],
  ["Sunset granny square", "fiberfiend_max", "Goals. Absolute goals. My first square is currently a rhombus.", 14],
  ["Flower garden squares", "grannysquaregwen", "Day 14 of square-a-day and honestly it's the best habit I've ever built.", 8],
  ["Flower garden squares", "stitchwitch_sam", "The flower centres against that cream border 😍", 9],
  ["Granny stripe blanket", "blanketstateofmind", "Stash-busting blankets always end up the best ones. The chaos is the charm.", 17],
  ["Granny stripe blanket", "yarnhoarder_jo", "'The color order is 100% vibes' is the most relatable thing on this app.", 18],
  ["Berry patch blanket", "grannysquaregwen", "Berry smoothie spilled on a cloud is EXACTLY it. Gorgeous palette.", 9],
  ["Berry patch blanket", "mira_makes", "The cat tax has been paid, the blanket is officially blessed.", 16],
  ["Seaside throw", "cozycorner_kate", "Wave stitch for a coast palette — the commitment to the theme! Stunning.", 15],
  ["Seaside throw", "hookandhome", "Please tell me you're keeping it. Some makes are too good to gift.", 16],
  ["Nesting baskets", "yarnhoarder_jo", "Rope core is the answer. Mine flop over like sad hats. Trying this.", 10],
  ["Nesting baskets", "cozycorner_kate", "Yarn, yarn, and yarn. The correct contents for all three.", 11],
  ["Tiny mug cozies", "stitchwitch_sam", "Completely unnecessary, completely essential — the crochet motto.", 2],
  ["The great stash sort", "cozycorner_kate", "Three identical teal skeins is honestly restrained. I found FIVE of the same grey.", 2],
  ["The great stash sort", "hookandhome", "The rainbow order shelf deserves to be framed.", 6],
  ["The great stash sort", "stitchwitch_sam", "'Bought more yarn to complete the gradient' — a tale as old as time.", 9],
  ["Watercolor wall hanging", "yarnhoarder_jo", "Four colors carried at once?? Witchcraft confirmed.", 7],
  ["Watercolor wall hanging", "blanketstateofmind", "The driftwood mount finishes it perfectly. This belongs in a shop.", 14],
  ["My first granny square", "grannysquaregwen", "Round three is where it clicks! Welcome to the granny square lifestyle 🧶", 5],
  ["My first granny square", "mira_makes", "'Looks like a square if you squint' — we have all been there. Keep going!", 5],
  ["My first granny square", "blanketstateofmind", "Six tutorial rewatches is the standard onboarding. You're right on schedule.", 6],
];

// liker usernames per project title (subset; everyone else random-ish but deterministic)
const LIKES: Record<string, string[]> = {
  "Mouse in a sweater": ["theloopylama", "grannysquaregwen", "cozycorner_kate", "blanketstateofmind", "hookandhome", "yarnhoarder_jo", "stitchwitch_sam", "fiberfiend_max"],
  "Cactus that never dies": ["theloopylama", "yarnhoarder_jo", "stitchwitch_sam", "fiberfiend_max"],
  "Amigurumi pals": ["mira_makes", "fiberfiend_max", "grannysquaregwen"],
  "Sunset granny square": ["cozycorner_kate", "blanketstateofmind", "fiberfiend_max", "mira_makes", "hookandhome", "stitchwitch_sam"],
  "Flower garden squares": ["stitchwitch_sam", "cozycorner_kate", "blanketstateofmind"],
  "Granny stripe blanket": ["blanketstateofmind", "yarnhoarder_jo", "grannysquaregwen", "fiberfiend_max"],
  "Berry patch blanket": ["grannysquaregwen", "mira_makes", "blanketstateofmind", "yarnhoarder_jo", "theloopylama"],
  "Seaside throw": ["cozycorner_kate", "hookandhome", "grannysquaregwen", "stitchwitch_sam", "mira_makes"],
  "Harvest ripple blanket": ["cozycorner_kate", "grannysquaregwen"],
  "Nesting baskets": ["yarnhoarder_jo", "cozycorner_kate", "mira_makes", "stitchwitch_sam"],
  "Tiny mug cozies": ["stitchwitch_sam", "yarnhoarder_jo", "mira_makes"],
  "The great stash sort": ["cozycorner_kate", "hookandhome", "stitchwitch_sam", "grannysquaregwen", "mira_makes"],
  "Watercolor wall hanging": ["yarnhoarder_jo", "blanketstateofmind", "hookandhome", "mira_makes", "grannysquaregwen"],
  "My first granny square": ["grannysquaregwen", "mira_makes", "blanketstateofmind", "theloopylama", "cozycorner_kate", "hookandhome"],
};

// owner -> collection -> project titles to save
const COLLECTIONS: Array<{ owner: string; name: string; description: string; titles: string[] }> = [
  { owner: "cozycorner_kate", name: "Blanket inspo", description: "Blankets I'm definitely making. Eventually. In order. Probably.", titles: ["Seaside throw", "Sunset granny square", "Harvest ripple blanket"] },
  { owner: "mira_makes", name: "Ami queue", description: "The to-make list that only ever grows.", titles: ["Amigurumi pals", "Cactus that never dies"] },
  { owner: "yarnhoarder_jo", name: "Colour palette ideas", description: "Saving these purely for the color combinations.", titles: ["Watercolor wall hanging", "Sunset granny square", "Berry patch blanket"] },
  { owner: "fiberfiend_max", name: "When I grow up", description: "Skills to aspire to. Current status: square-adjacent.", titles: ["Mouse in a sweater", "Granny stripe blanket", "Watercolor wall hanging"] },
];

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  if (!env.R2_ACCESS_KEY_ID || !env.R2_SECRET_ACCESS_KEY) {
    throw new Error("R2 credentials missing — run via `railway run` or set R2_* env vars.");
  }

  const existing = await prisma.user.findFirst({
    where: { email: { endsWith: `@${SEED_DOMAIN}` } },
    select: { id: true },
  });
  if (existing) {
    if (process.argv.includes("--reset")) {
      const removed = await prisma.user.deleteMany({
        where: { email: { endsWith: `@${SEED_DOMAIN}` } },
      });
      console.log(`--reset: removed ${removed.count} previous seed users (content cascades).`);
    } else {
      throw new Error("Seed users already exist. Re-run with --reset to wipe and reseed.");
    }
  }

  const passwordHash = await argon2.hash(DEMO_PASSWORD);

  // 1. Users (+ avatars)
  const userByName = new Map<string, { id: string }>();
  for (const p of PERSONAS) {
    const createdAt = daysAgo(p.joinedDaysAgo);
    const user = await prisma.user.create({
      data: {
        email: `${p.username}@${SEED_DOMAIN}`,
        passwordHash,
        username: p.username,
        displayName: p.displayName,
        bio: p.bio,
        interests: p.interests,
        onboardingCompleted: true,
        createdAt,
      },
    });
    if (p.avatar) {
      const photo = await createPhoto(user.id, p.avatar, createdAt);
      await prisma.user.update({ where: { id: user.id }, data: { avatarPhotoId: photo.id } });
    }
    userByName.set(p.username, user);
    console.log(`user @${p.username}`);
  }

  // 2. Projects + covers + logs
  const projectByTitle = new Map<string, { id: string; createdAt: Date; ownerId: string }>();
  for (const spec of PROJECTS) {
    const owner = userByName.get(spec.owner)!;
    const createdAt = daysAgo(spec.createdDaysAgo, Math.random() * 8);
    let coverPhotoId: string | null = null;
    if (spec.cover) {
      coverPhotoId = (await createPhoto(owner.id, spec.cover, createdAt)).id;
    }
    const project = await prisma.project.create({
      data: {
        ownerId: owner.id,
        title: spec.title,
        description: spec.description,
        craftType: spec.craftType,
        yarn: spec.yarn ?? null,
        yarnWeight: spec.yarnWeight ?? null,
        hookSize: spec.hookSize ?? null,
        status: spec.status,
        isPublic: true,
        coverPhotoId,
        createdAt,
        updatedAt: createdAt,
      },
    });
    projectByTitle.set(spec.title, { id: project.id, createdAt, ownerId: owner.id });

    for (const log of spec.logs) {
      const logDate = new Date(createdAt.getTime() + log.daysAfterProject * 86_400_000);
      let photoId: string | null = null;
      if (log.photo) {
        photoId = (await createPhoto(owner.id, log.photo, logDate)).id;
      }
      await prisma.progressLog.create({
        data: {
          projectId: project.id,
          note: log.note,
          rowCount: log.rowCount ?? null,
          hoursSpent: log.hoursSpent ?? null,
          photoId,
          createdAt: logDate,
        },
      });
    }
    console.log(`project "${spec.title}" (${spec.logs.length} logs)`);
  }

  // 3. Follows
  for (const [follower, following] of FOLLOWS) {
    await prisma.follow.create({
      data: {
        followerId: userByName.get(follower)!.id,
        followingId: userByName.get(following)!.id,
        createdAt: daysAgo(10 + Math.random() * 25),
      },
    });
  }
  console.log(`${FOLLOWS.length} follows`);

  // 4. Comments
  for (const [title, author, body, daysAfter] of COMMENTS) {
    const project = projectByTitle.get(title)!;
    await prisma.comment.create({
      data: {
        projectId: project.id,
        authorId: userByName.get(author)!.id,
        body,
        createdAt: new Date(project.createdAt.getTime() + daysAfter * 86_400_000 + Math.random() * 36e5),
      },
    });
  }
  console.log(`${COMMENTS.length} comments`);

  // 5. Likes
  let likeCount = 0;
  for (const [title, likers] of Object.entries(LIKES)) {
    const project = projectByTitle.get(title)!;
    for (const liker of likers) {
      await prisma.like.create({
        data: {
          userId: userByName.get(liker)!.id,
          projectId: project.id,
          createdAt: new Date(project.createdAt.getTime() + (1 + Math.random() * 10) * 86_400_000),
        },
      });
      likeCount++;
    }
  }
  console.log(`${likeCount} likes`);

  // 6. Collections
  for (const c of COLLECTIONS) {
    const owner = userByName.get(c.owner)!;
    const firstProject = projectByTitle.get(c.titles[0]!)!;
    // Reuse the first saved project's cover photo as the board cover.
    const coverPhoto = await prisma.project.findUnique({
      where: { id: firstProject.id },
      select: { coverPhotoId: true },
    });
    const collection = await prisma.collection.create({
      data: {
        ownerId: owner.id,
        name: c.name,
        description: c.description,
        isPublic: true,
        coverPhotoId: coverPhoto?.coverPhotoId ?? null,
        createdAt: daysAgo(8 + Math.random() * 15),
      },
    });
    for (const title of c.titles) {
      await prisma.collectionItem.create({
        data: { collectionId: collection.id, projectId: projectByTitle.get(title)!.id },
      });
    }
    console.log(`collection "${c.name}" (${c.titles.length} items)`);
  }

  console.log(`\nDone. ${uploadCount} images uploaded to R2.`);
  console.log(`Sign in as any persona, e.g. mira_makes@${SEED_DOMAIN} / ${DEMO_PASSWORD}`);
}

main()
  .catch((err) => {
    console.error("SEED FAILED:", err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
