import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Payload CMS Demo",
  description: "Local editing demo built with Next.js and Payload CMS",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return <>{children}</>;
}
