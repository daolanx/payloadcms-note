import type { Metadata } from 'next'
import { Noto_Serif_SC } from 'next/font/google'
import { Header } from '@/components/header'
import './globals.css'

const notoSerif = Noto_Serif_SC({
  variable: '--font-noto-serif',
  subsets: ['latin'],
  weight: ['400', '700'],
})

export const metadata: Metadata = {
  title: '道蓝的生活随笔',
  description: '生活，兴趣，感悟',
  icons: {
    icon: '/favico.png',
  },
  robots: {
    index: false,
    follow: false,
  },
}

export default function FrontendLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html
      lang="zh-CN"
      className={`${notoSerif.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <body className="min-h-full flex flex-col">
        <Header />
        <main className="flex-1">{children}</main>
        <footer className="border-t border-border py-6">
          <div className="container mx-auto px-6 max-w-2xl text-center text-xs text-muted-foreground tracking-wide space-y-1">
            <p>© {new Date().getFullYear()} 道蓝</p>
            <p>浙ICP备2026048697号-1</p>
          </div>
        </footer>
      </body>
    </html>
  )
}
