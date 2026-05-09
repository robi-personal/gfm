import { PDFDocument } from "pdf-lib";

export async function countPdfPages(base64: string): Promise<number> {
  const bytes = Buffer.from(base64, "base64");
  const doc   = await PDFDocument.load(bytes, { ignoreEncryption: true });
  return doc.getPageCount();
}

export function pdfQuotaCost(pages: number, pagesPerQuota: number): number {
  return Math.ceil(pages / pagesPerQuota);
}
