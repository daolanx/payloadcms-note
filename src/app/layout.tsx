import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "My Blog",
  description: "A blog built with Next.js and Payload CMS",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return <>{children}</>;
}
