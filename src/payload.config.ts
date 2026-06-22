import { sqliteAdapter } from '@payloadcms/db-sqlite'
import { lexicalEditor } from '@payloadcms/richtext-lexical'
import { buildConfig } from 'payload'

export default buildConfig({
  serverURL: process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000',
  admin: {
    user: 'users',
  },
  db: sqliteAdapter({
    client: {
      url: process.env.DATABASE_URI || 'file:./data/database.db',
    },
  }),
  editor: lexicalEditor(),
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
            { label: '男', value: 'male' },
            { label: '女', value: 'female' },
            { label: '其他', value: 'other' },
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
      slug: 'pages',
      admin: {
        useAsTitle: 'title',
      },
      fields: [
        { name: 'title', type: 'text', required: true },
        { name: 'slug', type: 'text', required: true, unique: true },
        { name: 'content', type: 'richText', editor: lexicalEditor() },
        {
          name: 'status',
          type: 'select',
          options: [
            { label: '草稿', value: 'draft' },
            { label: '已发布', value: 'published' },
          ],
          defaultValue: 'draft',
          required: true,
        },
      ],
    },
    {
      slug: 'media',
      upload: {
        staticDir: 'media',
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
