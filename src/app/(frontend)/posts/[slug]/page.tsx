import { notFound } from 'next/navigation'
import { PostImage } from '@/components/post-image'
import Link from 'next/link'
import { RichText } from '@payloadcms/richtext-lexical/react'
import type { Metadata } from 'next'
import { getPost, getAllPostSlugs } from '@/lib/posts'

export const revalidate = 60

type PageProps = {
  params: Promise<{ slug: string }>
}

export async function generateStaticParams() {
  const slugs = await getAllPostSlugs()
  return slugs.map((slug) => ({ slug }))
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  if (!post) return { title: 'Post not found' }

  return {
    title: post.title,
    description: post.excerpt || undefined,
  }
}

export default async function PostPage({ params }: PageProps) {
  const { slug } = await params
  const post = await getPost(slug)

  if (!post) {
    notFound()
  }

  return (
    <div className="min-h-screen bg-linear-to-br from-background via-background to-muted/20">
      <article className="container mx-auto px-4 py-12 max-w-3xl">
        {/* Back link */}
        <Link
          href="/"
          className="text-sm text-muted-foreground hover:text-foreground transition-colors mb-8 inline-block"
        >
          ← Back to posts
        </Link>

        {/* Cover Image */}
        {post.coverImage?.url && (
          <div className="relative w-full aspect-[16/9] mb-8 rounded-lg overflow-hidden">
            <PostImage
              src={post.coverImage.url}
              alt={post.coverImage.alt || post.title}
              className="object-cover"
              sizes="(max-width: 768px) 100vw, 768px"
            />
          </div>
        )}

        {/* Meta */}
        <div className="mb-6">
          {post.publishedAt && (
            <time className="text-sm text-muted-foreground">
              {new Date(post.publishedAt).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
              })}
            </time>
          )}
        </div>

        {/* Title */}
        <h1 className="text-3xl sm:text-4xl font-bold tracking-tight text-foreground mb-8">
          {post.title}
        </h1>

        {/* Content */}
        {post.content && (
          <div className="prose prose-neutral dark:prose-invert max-w-none">
            <RichText data={post.content} />
          </div>
        )}
      </article>
    </div>
  )
}
