// Typed HTTP errors. Throw these from handlers; the global error handler in
// server.ts serializes them to { error: { code, message } }.
export class HttpError extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export const badRequest = (msg = "Bad request", code = "bad_request") =>
  new HttpError(400, code, msg);
export const unauthorized = (msg = "Unauthorized", code = "unauthorized") =>
  new HttpError(401, code, msg);
export const forbidden = (msg = "Forbidden", code = "forbidden") =>
  new HttpError(403, code, msg);
export const notFound = (msg = "Not found", code = "not_found") =>
  new HttpError(404, code, msg);
export const conflict = (msg = "Conflict", code = "conflict") =>
  new HttpError(409, code, msg);
