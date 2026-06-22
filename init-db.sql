-- Payload CMS SQLite schema (auto-generated)
-- Only table structure, no data.

CREATE TABLE IF NOT EXISTS `users_sessions` (
	`_order` integer NOT NULL,
	`_parent_id` integer NOT NULL,
	`id` text PRIMARY KEY NOT NULL,
	`created_at` text,
	`expires_at` text NOT NULL,
	FOREIGN KEY (`_parent_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX IF NOT EXISTS `users_sessions_order_idx` ON `users_sessions` (`_order`);
CREATE INDEX IF NOT EXISTS `users_sessions_parent_id_idx` ON `users_sessions` (`_parent_id`);

CREATE TABLE IF NOT EXISTS `users` (
	`id` integer PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`gender` text NOT NULL,
	`avatar_id` integer,
	`updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`email` text NOT NULL,
	`reset_password_token` text,
	`reset_password_expiration` text,
	`salt` text,
	`hash` text,
	`login_attempts` numeric DEFAULT 0,
	`lock_until` text,
	FOREIGN KEY (`avatar_id`) REFERENCES `media`(`id`) ON UPDATE no action ON DELETE set null
);
CREATE INDEX IF NOT EXISTS `users_avatar_idx` ON `users` (`avatar_id`);
CREATE INDEX IF NOT EXISTS `users_updated_at_idx` ON `users` (`updated_at`);
CREATE INDEX IF NOT EXISTS `users_created_at_idx` ON `users` (`created_at`);
CREATE UNIQUE INDEX IF NOT EXISTS `users_email_idx` ON `users` (`email`);

CREATE TABLE IF NOT EXISTS `pages` (
	`id` integer PRIMARY KEY NOT NULL,
	`title` text NOT NULL,
	`slug` text NOT NULL,
	`content` text,
	`status` text DEFAULT 'draft' NOT NULL,
	`updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS `pages_slug_idx` ON `pages` (`slug`);
CREATE INDEX IF NOT EXISTS `pages_updated_at_idx` ON `pages` (`updated_at`);
CREATE INDEX IF NOT EXISTS `pages_created_at_idx` ON `pages` (`created_at`);

CREATE TABLE IF NOT EXISTS `media` (
	`id` integer PRIMARY KEY NOT NULL,
	`alt` text,
	`updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`url` text,
	`thumbnail_u_r_l` text,
	`filename` text,
	`mime_type` text,
	`filesize` numeric,
	`width` numeric,
	`height` numeric,
	`focal_x` numeric,
	`focal_y` numeric
);
CREATE INDEX IF NOT EXISTS `media_updated_at_idx` ON `media` (`updated_at`);
CREATE INDEX IF NOT EXISTS `media_created_at_idx` ON `media` (`created_at`);
CREATE UNIQUE INDEX IF NOT EXISTS `media_filename_idx` ON `media` (`filename`);

CREATE TABLE IF NOT EXISTS `payload_kv` (
	`id` integer PRIMARY KEY NOT NULL,
	`key` text NOT NULL,
	`data` text NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS `payload_kv_key_idx` ON `payload_kv` (`key`);

CREATE TABLE IF NOT EXISTS `payload_locked_documents` (
	`id` integer PRIMARY KEY NOT NULL,
	`global_slug` text,
	`updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_global_slug_idx` ON `payload_locked_documents` (`global_slug`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_updated_at_idx` ON `payload_locked_documents` (`updated_at`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_created_at_idx` ON `payload_locked_documents` (`created_at`);

CREATE TABLE IF NOT EXISTS `payload_locked_documents_rels` (
	`id` integer PRIMARY KEY NOT NULL,
	`order` integer,
	`parent_id` integer NOT NULL,
	`path` text NOT NULL,
	`users_id` integer,
	`pages_id` integer,
	`media_id` integer,
	FOREIGN KEY (`parent_id`) REFERENCES `payload_locked_documents`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`users_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`pages_id`) REFERENCES `pages`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`media_id`) REFERENCES `media`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_rels_order_idx` ON `payload_locked_documents_rels` (`order`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_rels_parent_idx` ON `payload_locked_documents_rels` (`parent_id`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_rels_path_idx` ON `payload_locked_documents_rels` (`path`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_rels_users_id_idx` ON `payload_locked_documents_rels` (`users_id`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_rels_pages_id_idx` ON `payload_locked_documents_rels` (`pages_id`);
CREATE INDEX IF NOT EXISTS `payload_locked_documents_rels_media_id_idx` ON `payload_locked_documents_rels` (`media_id`);

CREATE TABLE IF NOT EXISTS `payload_preferences` (
	`id` integer PRIMARY KEY NOT NULL,
	`key` text,
	`value` text,
	`updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX IF NOT EXISTS `payload_preferences_key_idx` ON `payload_preferences` (`key`);
CREATE INDEX IF NOT EXISTS `payload_preferences_updated_at_idx` ON `payload_preferences` (`updated_at`);
CREATE INDEX IF NOT EXISTS `payload_preferences_created_at_idx` ON `payload_preferences` (`created_at`);

CREATE TABLE IF NOT EXISTS `payload_preferences_rels` (
	`id` integer PRIMARY KEY NOT NULL,
	`order` integer,
	`parent_id` integer NOT NULL,
	`path` text NOT NULL,
	`users_id` integer,
	FOREIGN KEY (`parent_id`) REFERENCES `payload_preferences`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`users_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX IF NOT EXISTS `payload_preferences_rels_order_idx` ON `payload_preferences_rels` (`order`);
CREATE INDEX IF NOT EXISTS `payload_preferences_rels_parent_idx` ON `payload_preferences_rels` (`parent_id`);
CREATE INDEX IF NOT EXISTS `payload_preferences_rels_path_idx` ON `payload_preferences_rels` (`path`);
CREATE INDEX IF NOT EXISTS `payload_preferences_rels_users_id_idx` ON `payload_preferences_rels` (`users_id`);

CREATE TABLE IF NOT EXISTS `payload_migrations` (
	`id` integer PRIMARY KEY NOT NULL,
	`name` text,
	`batch` numeric,
	`updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
	`created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX IF NOT EXISTS `payload_migrations_updated_at_idx` ON `payload_migrations` (`updated_at`);
CREATE INDEX IF NOT EXISTS `payload_migrations_created_at_idx` ON `payload_migrations` (`created_at`);
