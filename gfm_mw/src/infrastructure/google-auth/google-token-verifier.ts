import { OAuth2Client } from "google-auth-library";
import { env } from "../../config/env";

const client = new OAuth2Client(env.GOOGLE_CLIENT_ID);

const acceptedAudiences = [
  env.GOOGLE_CLIENT_ID,
  ...(env.GOOGLE_IOS_CLIENT_ID ? [env.GOOGLE_IOS_CLIENT_ID] : []),
];

export interface VerifiedToken {
  sub: string;
  email: string;
}

export async function verifyGoogleIdToken(token: string): Promise<VerifiedToken> {
  const ticket = await client.verifyIdToken({
    idToken: token,
    audience: acceptedAudiences,
  });

  const payload = ticket.getPayload();

  if (!payload?.sub || !payload.email) {
    throw new Error("Token payload missing sub or email");
  }

  return { sub: payload.sub, email: payload.email };
}
