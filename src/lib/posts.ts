import { unstable_cache } from 'next/cache'
import { getPayload } from 'payload'
import config from '@payload-config'

export interface Post {
  id: number
  title: string
  excerpt?: string | null
  coverImage?: {
    url: string
    alt?: string | null
  } | null
  content?: any
  status: 'draft' | 'published'
  publishedAt?: string | null
  createdAt?: string | null
}

export const getPosts = unstable_cache(
  async (): Promise<Post[]> => {
    try {
      const payload = await getPayload({ config })
      const result = await payload.find({
        collection: 'posts',
        where: { status: { equals: 'published' } },
        sort: '-publishedAt',
        limit: 20,
      })
      return result.docs as Post[]
    } catch (error) {
      console.error('Failed to fetch posts:', error)
      return []
    }
  },
  ['posts-list'],
  { tags: ['posts'] },
)

export const getPost = unstable_cache(
  async (id: number): Promise<Post | null> => {
    try {
      const payload = await getPayload({ config })
      const result = await payload.find({
        collection: 'posts',
        where: {
          and: [
            { id: { equals: id } },
            { status: { equals: 'published' } },
          ],
        },
        depth: 2,
        limit: 1,
      })
      return (result.docs[0] as Post) || null
    } catch (error) {
      console.error('Failed to fetch post:', error)
      return null
    }
  },
  ['posts-detail'],
  { tags: ['posts'] },
)

export async function getAllPostIds(): Promise<number[]> {
  if (process.env.IS_DOCKER_BUILD === 'true') {
    return []
  }

  try {
    const payload = await getPayload({ config })
    const result = await payload.find({
      collection: 'posts',
      where: { status: { equals: 'published' } },
      select: { id: true },
      limit: 100,
    })
    return result.docs.map((doc) => doc.id as number)
  } catch (error) {
    console.error('Failed to fetch post ids:', error)
    return []
  }
}
