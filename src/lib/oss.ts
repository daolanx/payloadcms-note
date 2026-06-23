/**
 * Build OSS virtual-hosted style base URL.
 *
 * Virtual-hosted: https://{bucket}.{endpoint-host}/
 * Path-style (forbidden): https://endpoint/{bucket}/
 */
function ossBase(): string {
  const endpoint = process.env.OSS_ENDPOINT // https://oss-cn-beijing.aliyuncs.com
  const bucket = process.env.OSS_BUCKET     // payload-cms
  if (!endpoint || !bucket) return ''

  const url = new URL(endpoint)
  return `${url.protocol}//${bucket}.${url.hostname}`
}

/**
 * Convert Payload proxy URL to direct OSS URL.
 *
 * Payload URL:  http://localhost:3000/api/media/file/big.webp
 * OSS URL:      https://payload-cms.oss-cn-beijing.aliyuncs.com/big.webp
 */
export function payloadToOssUrl(payloadUrl: string): string {
  const filename = payloadUrl.split('/').pop()
  if (!filename) return payloadUrl

  const base = ossBase()
  if (!base) return payloadUrl

  return `${base}/${filename}`
}

/**
 * Build an OSS image processing URL.
 *
 * Example: https://payload-cms.oss-cn-beijing.aliyuncs.com/big.webp?x-oss-process=image/resize,w_640/format,webp/quality,q_80
 */
export function ossImageUrl(
  filename: string,
  options?: {
    width?: number
    format?: 'webp' | 'png' | 'jpg'
    quality?: number
  },
): string {
  const base = ossBase()
  if (!base) return filename

  const url = `${base}/${filename}`
  if (!options) return url

  const params: string[] = []
  if (options.width) params.push(`resize,w_${options.width}`)
  if (options.format) params.push(`format,${options.format}`)
  if (options.quality) params.push(`quality,q_${options.quality}`)

  return params.length ? `${url}?x-oss-process=image/${params.join('/')}` : url
}
