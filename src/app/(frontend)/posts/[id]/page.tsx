import { notFound } from 'next/navigation'
import { PostImage } from '@/components/post-image'
import Link from 'next/link'
import { RichText } from '@payloadcms/richtext-lexical/react'
import type { Metadata } from 'next'
import { getPost } from '@/lib/posts'

type PageProps = {
  params: Promise<{ id: string }>
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params
  const post = await getPost(Number(id))
  if (!post) return { title: '文章未找到' }

  return {
    title: post.title,
    description: post.excerpt || undefined,
  }
}

export default async function PostPage({ params }: PageProps) {
  const { id } = await params
  const post = await getPost(Number(id))

  if (!post) {
    notFound()
  }

  return (
    <div className="min-h-screen">
      <article className="container mx-auto px-6 py-16 max-w-2xl">
        <Link
          href="/"
          className="text-sm text-muted-foreground hover:text-foreground transition-colors mb-12 inline-block tracking-wide"
        >
          ← 返回
        </Link>

        {post.coverImage?.url && (
          <div className="relative w-full aspect-[16/9] mb-10 overflow-hidden">
            <PostImage
              src={post.coverImage.url}
              alt={post.coverImage.alt || post.title}
              className="object-cover"
              sizes="(max-width: 768px) 100vw, 768px"
            />
          </div>
        )}

        {post.publishedAt && (
          <time className="text-sm text-muted-foreground tracking-widest block mb-4">
            {new Date(post.publishedAt).toLocaleDateString('zh-CN', {
              year: 'numeric',
              month: 'long',
              day: 'numeric',
            })}
          </time>
        )}

        <h1 className="text-2xl sm:text-3xl font-bold text-foreground leading-relaxed mb-10">
          {post.title}
        </h1>

        {post.content && (
          <div className="prose prose-neutral max-w-none">
            <RichText data={post.content} />
          </div>
        )}
      </article>
    </div>
  )
}
