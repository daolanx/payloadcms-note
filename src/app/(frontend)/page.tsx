import Link from 'next/link'
import { PostImage } from '@/components/post-image'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { getPosts } from '@/lib/posts'

export const dynamic = 'force-dynamic'

export default async function Home() {
  const posts = await getPosts()

  return (
    <div className="min-h-screen bg-linear-to-br from-background via-background to-muted/20">
      <div className="container mx-auto px-4 py-12 max-w-4xl">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold tracking-tight text-foreground">
            Latest Posts
          </h1>
          <p className="text-muted-foreground mt-1">
            {posts.length} {posts.length === 1 ? 'post' : 'posts'} total
          </p>
        </div>

        {/* Post List */}
        {posts.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <p className="text-muted-foreground mb-4">No posts yet</p>
              <Link
                href="/admin/collections/posts/create"
                className="text-sm text-primary underline underline-offset-4 hover:opacity-80"
              >
                Create your first post
              </Link>
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-6">
            {posts.map((post) => (
              <Link key={post.id} href={`/posts/${post.slug}`}>
                <Card className="hover:shadow-md transition-shadow cursor-pointer overflow-hidden">
                  <div className="flex flex-col sm:flex-row">
                    {post.coverImage?.url && (
                      <div className="relative w-full sm:w-48 h-48 sm:h-auto shrink-0">
                        <PostImage
                          src={post.coverImage.url}
                          alt={post.coverImage.alt || post.title}
                          className="object-cover"
                          sizes="(max-width: 640px) 100vw, 192px"
                        />
                      </div>
                    )}
                    <CardContent className="py-5 flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <Badge variant="secondary">
                          {post.status === 'published' ? 'Published' : 'Draft'}
                        </Badge>
                        {post.publishedAt && (
                          <span className="text-xs text-muted-foreground">
                            {new Date(post.publishedAt).toLocaleDateString('en-US')}
                          </span>
                        )}
                      </div>
                      <h2 className="text-xl font-semibold text-foreground mb-2 line-clamp-2">
                        {post.title}
                      </h2>
                      {post.excerpt && (
                        <p className="text-muted-foreground text-sm line-clamp-2">
                          {post.excerpt}
                        </p>
                      )}
                    </CardContent>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
