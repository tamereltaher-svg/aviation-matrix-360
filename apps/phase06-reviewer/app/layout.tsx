import "./globals.css";
export const metadata = { title: "Phase 06 Reviewer", description: "Human QA workspace" };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
