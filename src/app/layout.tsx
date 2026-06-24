import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "My Notes",
  description: "A notes app built with Next.js and Payload CMS",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return <>{children}</>;
}
