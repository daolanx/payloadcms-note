import Link from 'next/link'
import { getPosts } from '@/lib/posts'

export const revalidate = 60

export default async function Home() {
  const posts = await getPosts()

  return (
    <div>
      <div className="container mx-auto p-6 max-w-2xl">
        {posts.length === 0 ? (
          <div className="py-16 text-center">
            <p className="text-muted-foreground tracking-widest text-sm">暂无文章</p>
          </div>
        ) : (
          <ul className="divide-y divide-border">
            {posts.map((post) => {
              const date = post.publishedAt || post.createdAt
              const formatted = date
                ? new Date(date).toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric' })
                : ''
              return (
                <li key={post.id}>
                  <Link
                    href={`/posts/${post.id}`}
                    className="flex items-baseline gap-4 py-5 group"
                  >
                    {formatted && (
                      <span className="text-base text-muted-foreground shrink-0 tabular-nums">
                        {formatted}
                      </span>
                    )}
                    <span className="text-base text-foreground group-hover:underline truncate">
                      {post.title}
                    </span>
                  </Link>
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </div>
  )
}
