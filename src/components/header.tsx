import Link from 'next/link'
import { buttonVariants } from '@/components/ui/button'

export function Header() {
  return (
    <header className="border-b border-border bg-background/80 backdrop-blur-sm sticky top-0 z-50">
      <div className="container mx-auto px-4 max-w-4xl h-14 flex items-center justify-between">
        <Link href="/" className="text-lg font-bold tracking-tight text-foreground hover:opacity-80 transition-opacity">
          My Blog
        </Link>
        <Link
          href="/admin"
          className={buttonVariants({ variant: 'outline', size: 'sm' })}
        >
          Dashboard
        </Link>
      </div>
    </header>
  )
}
