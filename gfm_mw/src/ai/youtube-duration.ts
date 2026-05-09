import { env } from "../config/env";

// Parses ISO 8601 duration (PT1H2M3S) → minutes, rounded up.
export function parseDurationMinutes(iso: string): number {
  const m = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!m) return 0;
  const hours   = parseInt(m[1] ?? "0", 10);
  const minutes = parseInt(m[2] ?? "0", 10);
  const seconds = parseInt(m[3] ?? "0", 10);
  const totalSeconds = hours * 3600 + minutes * 60 + seconds;
  return Math.ceil(totalSeconds / 60);
}

// Extracts video ID from a YouTube URL (watch or short form).
export function extractVideoId(url: string): string | null {
  const m = url.match(/(?:v=|youtu\.be\/)([A-Za-z0-9_-]{11})/);
  return m ? m[1] : null;
}

// Fetches duration in minutes for a YouTube video via Data API v3.
// Returns null if YOUTUBE_API_KEY is not configured (skip cap check).
// Throws if the video is not found or the API call fails.
export async function fetchYoutubeDurationMinutes(youtubeUrl: string): Promise<number | null> {
  if (!env.YOUTUBE_API_KEY) return null;

  const videoId = extractVideoId(youtubeUrl);
  if (!videoId) throw new Error("invalid_youtube_url");

  const url = `https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=${videoId}&key=${env.YOUTUBE_API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`youtube_api_error_${res.status}`);

  const data = await res.json() as {
    items?: Array<{ contentDetails?: { duration?: string } }>;
  };

  const item = data.items?.[0];
  if (!item) throw new Error("youtube_unavailable");

  const duration = item.contentDetails?.duration;
  if (!duration) throw new Error("youtube_unavailable");

  return parseDurationMinutes(duration);
}
