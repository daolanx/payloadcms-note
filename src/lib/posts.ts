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

export async function getPosts(): Promise<Post[]> {
  const payload = await getPayload({ config })
  const result = await payload.find({
    collection: 'posts',
    where: { status: { equals: 'published' } },
    sort: '-publishedAt',
    limit: 20,
  })
  return result.docs as Post[]
}

export async function getPost(id: number): Promise<Post | null> {
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
}
