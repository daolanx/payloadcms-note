import Link from 'next/link'

export function Header() {
  return (
    <header className="border-b border-border">
      <div className="container mx-auto px-6 max-w-2xl h-16 flex items-center">
        <Link href="/" className="text-lg font-bold text-foreground hover:text-muted-foreground transition-colors">
          道蓝的生活随笔
        </Link>
      </div>
    </header>
  )
}
