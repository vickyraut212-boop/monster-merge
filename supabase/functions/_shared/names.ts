// Player display names for the leaderboard: random fun names for new players,
// and the rules a player-chosen name must follow.

const ADJECTIVES = [
  "Bouncy", "Sleepy", "Giggly", "Fuzzy", "Wobbly", "Sneaky", "Happy", "Grumpy",
  "Sparkly", "Squishy", "Zappy", "Cosmic", "Tiny", "Mighty", "Jolly", "Goofy",
];

const MONSTERS = [
  "Blob", "Goo", "Zork", "Bloop", "Muncher", "Gloop", "Fuzzball", "Squish",
  "Alien", "Critter", "Wiggle", "Noodle", "Boss", "Pudding", "Jelly", "Slime",
];

export const NAME_MIN = 3;
export const NAME_MAX = 16;

// Letters, digits, spaces, underscores and dashes only.
const NAME_PATTERN = /^[A-Za-z0-9 _-]+$/;

// Small blocklist, checked as substrings with spaces/underscores/dashes removed.
// Extend as needed; it is a first line of defence, not full moderation.
const BLOCKED = [
  "fuck", "shit", "bitch", "cunt", "dick", "pussy", "nigg", "fag", "rape",
  "nazi", "hitler", "whore", "slut", "porn", "admin", "moderator", "supabase",
];

function pick<T>(items: T[]): T {
  return items[Math.floor(Math.random() * items.length)];
}

/** For example "Bouncy Blob 4821". Always 3..16 characters and valid. */
export function randomName(): string {
  for (;;) {
    const digits = String(Math.floor(1000 + Math.random() * 9000));
    const name = `${pick(ADJECTIVES)} ${pick(MONSTERS)} ${digits}`;
    if (name.length <= NAME_MAX) return name;
  }
}

/**
 * Returns the cleaned name (trimmed, inner spaces collapsed), or an error
 * message the game can show the player.
 */
export function validateName(raw: unknown): { name: string } | { error: string } {
  if (typeof raw !== "string") return { error: "Name is missing." };
  const name = raw.trim().replace(/\s+/g, " ");
  if (name.length < NAME_MIN || name.length > NAME_MAX) {
    return { error: `Name must be ${NAME_MIN} to ${NAME_MAX} characters.` };
  }
  if (!NAME_PATTERN.test(name)) {
    return { error: "Use only letters, numbers, spaces, _ and -." };
  }
  const squashed = name.toLowerCase().replace(/[ _-]/g, "");
  if (BLOCKED.some((word) => squashed.includes(word))) {
    return { error: "Please pick a different name." };
  }
  return { name };
}
