'use client'

import Image from 'next/image'
import ossLoader from '@/lib/image-loader'

interface PostImageProps {
  src: string
  alt: string
  className?: string
  sizes?: string
}

/**
 * Responsive image component.
 *
 * Uses OSS loader to serve resized images directly from Alibaba Cloud OSS.
 * - Small devices: small width param → small image → less bandwidth
 * - Large devices: large width param → large image → sharp display
 * - OSS handles format conversion (WebP) and caching at CDN edge
 */
export function PostImage({ src, alt, className, sizes }: PostImageProps) {
  return (
    <Image
      src={src}
      alt={alt}
      fill
      loader={ossLoader}
      className={className}
      sizes={sizes}
      suppressHydrationWarning
    />
  )
}
