export const KRIM_STAGING_PROJECT_URL = "https://qrpcivhdxobiaofppbkl.supabase.co";

export function isKrimStagingProjectUrl(value: string | null | undefined): boolean {
  if (!value) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" &&
      parsed.hostname === "qrpcivhdxobiaofppbkl.supabase.co" &&
      parsed.port === "" &&
      parsed.username === "" &&
      parsed.password === "" &&
      parsed.pathname === "/" &&
      parsed.search === "" &&
      parsed.hash === "";
  } catch {
    return false;
  }
}
