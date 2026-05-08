import { Request, Response, NextFunction } from "express";

// api-contract.md §2.5 error envelope
interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorMiddleware(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  // Body-parser 413
  if (
    typeof err === "object" &&
    err !== null &&
    "type" in err &&
    (err as { type: string }).type === "entity.too.large"
  ) {
    res.status(400).json({
      code: "invalid_input",
      message: "Request body too large.",
    } satisfies ApiError);
    return;
  }

  if (err instanceof HttpError) {
    res.status(err.statusCode).json({
      code: err.code,
      message: err.message,
      ...(err.details ? { details: err.details } : {}),
    } satisfies ApiError);
    return;
  }

  // Unexpected error — log and return a generic 500.
  // Sentry capture is added in Task 16.
  req.log?.error({ err }, "unhandled_error");
  res.status(500).json({
    code: "internal_error",
    message: "An unexpected error occurred.",
  } satisfies ApiError);
}
