import { revalidatePath } from 'next/cache'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  const secret = request.headers.get('x-revalidate-secret')
  const expectedSecret = process.env.REVALIDATION_SECRET

  if (!expectedSecret || secret !== expectedSecret) {
    return NextResponse.json({ error: 'Invalid or unconfigured secret' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const id = body?.id

    // Invalidate page cache
    revalidatePath('/', 'page')
    if (id) {
      revalidatePath(`/posts/${id}`, 'page')
    }

    return NextResponse.json({
      revalidated: true,
      id: id || 'home-only',
      timestamp: Date.now(),
    })
  } catch (error) {
    return NextResponse.json(
      { error: 'Error revalidating', details: error instanceof Error ? error.message : String(error) },
      { status: 500 },
    )
  }
}
