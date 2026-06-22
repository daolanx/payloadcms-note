import Link from 'next/link'
import { Card, CardContent } from '@/components/ui/card'
import { buttonVariants } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { getPayload } from 'payload'
import config from '@payload-config'
import { cn } from '@/lib/utils'

interface User {
  id: number
  name: string
  email: string
  gender: 'male' | 'female' | 'other'
  avatar?: {
    url: string
    alt: string
  } | null
}

const genderLabels: Record<string, string> = {
  male: '男',
  female: '女',
  other: '其他',
}

const genderBadgeVariant: Record<string, 'default' | 'secondary' | 'outline'> = {
  male: 'default',
  female: 'secondary',
  other: 'outline',
}

export default async function Home() {
  let users: User[] = []

  try {
    const payload = await getPayload({ config })
    const result = await payload.find({
      collection: 'users',
      limit: 100,
    })
    users = result.docs as User[]
  } catch (error) {
    console.error('Failed to fetch users:', error)
  }

  return (
    <div className="min-h-screen bg-linear-to-br from-background via-background to-muted/20">
      <div className="container mx-auto px-4 py-12 max-w-4xl">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-foreground">
              用户列表
            </h1>
            <p className="text-muted-foreground mt-1">
              共 {users.length} 位用户
            </p>
          </div>
          <Link href="/admin/collections/users/create" className={buttonVariants()}>
            + 添加用户
          </Link>
        </div>

        {/* User List */}
        {users.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <p className="text-muted-foreground mb-4">暂无用户数据</p>
              <Link href="/admin/collections/users/create" className={buttonVariants({ variant: 'outline' })}>
                创建第一个用户
              </Link>
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-4">
            {users.map((user) => (
              <Card key={user.id} className="hover:shadow-md transition-shadow">
                <CardContent className="py-4">
                  <div className="flex items-center gap-4">
                    <Avatar className="h-12 w-12">
                      <AvatarImage
                        src={user.avatar?.url}
                        alt={user.name}
                      />
                      <AvatarFallback>
                        {user.name.slice(0, 2).toUpperCase()}
                      </AvatarFallback>
                    </Avatar>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <h3 className="font-medium text-foreground truncate">
                          {user.name}
                        </h3>
                        <Badge variant={genderBadgeVariant[user.gender] || 'outline'}>
                          {genderLabels[user.gender] || user.gender}
                        </Badge>
                      </div>
                      <p className="text-sm text-muted-foreground truncate">
                        {user.email}
                      </p>
                    </div>

                    <Link
                      href={`/admin/collections/users/${user.id}`}
                      className={cn(buttonVariants({ variant: 'ghost', size: 'sm' }))}
                    >
                      编辑
                    </Link>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
