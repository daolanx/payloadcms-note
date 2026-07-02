import { revalidatePath, revalidateTag } from 'next/cache'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  const secret = request.headers.get('x-revalidate-secret')

  if (secret !== process.env.REVALIDATION_SECRET) {
    return NextResponse.json({ error: 'Invalid secret' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const slug = body?.slug

    // Invalidate unstable_cache data (tagged in posts.ts)
    revalidateTag('posts', '')

    // Invalidate page caches
    revalidatePath('/')
    if (slug) {
      revalidatePath(`/posts/${slug}`)
    }

    return NextResponse.json({
      revalidated: true,
      slug: slug || 'home-only',
      timestamp: Date.now(),
    })
  } catch (error) {
    return NextResponse.json(
      { error: 'Error revalidating', details: error instanceof Error ? error.message : String(error) },
      { status: 500 },
    )
  }
}
