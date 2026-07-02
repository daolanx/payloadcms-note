import { sqliteAdapter } from '@payloadcms/db-sqlite'
import { migrations } from './migrations'
import { lexicalEditor, FixedToolbarFeature, UploadFeature } from '@payloadcms/richtext-lexical'
import { s3Storage } from '@payloadcms/storage-s3'
import { buildConfig } from 'payload'

const SITE_URL = process.env.SITE_URL || 'http://localhost:3000'

const triggerRevalidate = async ({ doc }: { doc: any }) => {
  const url = `${SITE_URL}/api/revalidate`
  try {
    await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-revalidate-secret': process.env.REVALIDATION_SECRET || '',
      },
      body: JSON.stringify({ collection: 'posts', slug: doc?.slug }),
    })
  } catch (error) {
    console.error('Revalidation failed:', error)
  }
}

export default buildConfig({
  serverURL: SITE_URL,
  cors: [SITE_URL],
  csrf: [SITE_URL, 'http://localhost:3000'],
  routes: {
    admin: '/trail',
  },
  admin: {
    user: 'users',
  },
  db: sqliteAdapter({
    client: {
      url: process.env.DATABASE_URI || 'file:./db/database.db',
    },
    push: process.env.NODE_ENV !== 'production',
    // Auto-run migrations in production (push is dev-only)
    // See: docs/sqlite-production-migration.md
    prodMigrations: migrations,
  }),
  editor: lexicalEditor({
    features: ({ defaultFeatures }) => [
      ...defaultFeatures,
      FixedToolbarFeature(),
      UploadFeature({
        enabledCollections: ['media'],
      }),
    ],
  }),
  plugins: [
    s3Storage({
      collections: {
        media: true,
      },
      bucket: process.env.OSS_BUCKET || '',
      acl: 'public-read',
      config: {
        endpoint: process.env.OSS_ENDPOINT || '',
        region: 'oss-cn-beijing',
        credentials: {
          accessKeyId: process.env.OSS_ACCESS_KEY_ID || '',
          secretAccessKey: process.env.OSS_ACCESS_KEY_SECRET || '',
        },
      },
    }),
  ],
  collections: [
    {
      slug: 'users',
      auth: true,
      admin: {
        useAsTitle: 'name',
      },
      fields: [
        {
          name: 'name',
          type: 'text',
          required: true,
        },
        {
          name: 'gender',
          type: 'select',
          options: [
            { label: 'Male', value: 'male' },
            { label: 'Female', value: 'female' },
            { label: 'Other', value: 'other' },
          ],
          required: true,
        },
        {
          name: 'avatar',
          type: 'upload',
          relationTo: 'media',
        },
      ],
    },
    {
      slug: 'posts',
      admin: {
        useAsTitle: 'title',
        defaultColumns: ['title', 'status', 'publishedAt'],
      },
      hooks: {
        afterChange: [triggerRevalidate],
        afterDelete: [triggerRevalidate],
      },
      fields: [
        { name: 'title', type: 'text', required: true },
        {
          name: 'coverImage',
          type: 'upload',
          relationTo: 'media',
        },
        { name: 'excerpt', type: 'text' },
        { name: 'content', type: 'richText' },
        {
          name: 'status',
          type: 'select',
          options: [
            { label: 'Draft', value: 'draft' },
            { label: 'Published', value: 'published' },
          ],
          defaultValue: 'draft',
          required: true,
        },
        {
          name: 'publishedAt',
          type: 'date',
          admin: {
            position: 'sidebar',
          },
        },
      ],
    },
    {
      slug: 'media',
      upload: {
        mimeTypes: ['image/*'],
      },
      admin: {
        useAsTitle: 'alt',
      },
      access: {
        read: () => true,
      },
      fields: [
        { name: 'alt', type: 'text' },
      ],
    },
  ],
  secret: process.env.PAYLOAD_SECRET || 'default-secret-change-me',
  typescript: {
    outputFile: 'src/payload-types.ts',
  },
})
