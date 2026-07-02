import { revalidatePath, revalidateTag } from 'next/cache'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  const secret = request.headers.get('x-revalidate-secret')

  if (secret !== process.env.REVALIDATION_SECRET) {
    return NextResponse.json({ error: 'Invalid secret' }, { status: 401 })
  }

  try {
    // Revalidate the homepage and all post detail pages
    revalidateTag('posts')
    revalidatePath('/')
    revalidatePath('/posts/[slug]', 'page')

    return NextResponse.json({
      revalidated: true,
      timestamp: Date.now(),
    })
  } catch (error) {
    return NextResponse.json(
      { error: 'Error revalidating' },
      { status: 500 },
    )
  }
}
