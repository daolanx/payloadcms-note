import type { ImageLoaderProps } from 'next/image'

/**
 * Custom image loader for Alibaba Cloud OSS.
 *
 * Payload returns:  http://localhost:3000/api/media/file/big.webp
 * Loader outputs:   https://payload-cms.oss-cn-beijing.aliyuncs.com/big.webp?x-oss-process=image/resize,w_640
 *
 * OSS requires virtual-hosted style: {bucket}.{endpoint}/{filename}
 * OSS resizes the image on-the-fly — small devices get small images, large devices get large ones.
 */
export default function ossLoader({ src, width }: ImageLoaderProps): string {
  // Extract filename from Payload URL: /api/media/file/big.webp → big.webp
  const filename = src.split('/').pop() || src

  const endpoint = process.env.NEXT_PUBLIC_OSS_ENDPOINT // https://oss-cn-beijing.aliyuncs.com
  const bucket = process.env.NEXT_PUBLIC_OSS_BUCKET     // payload-cms

  if (!endpoint || !bucket) {
    return src
  }

  // Virtual-hosted style: https://{bucket}.{endpoint-host}/{filename}
  const url = new URL(endpoint)
  const host = `${bucket}.${url.hostname}`

  // OSS image processing: resize to requested width
  return `${url.protocol}//${host}/${filename}?x-oss-process=image/resize,w_${width}`
}
