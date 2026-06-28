CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========== PROFILES ===========
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  bio TEXT DEFAULT '',
  institution TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$ BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
 $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =========== RESOURCES ===========
CREATE TABLE public.resources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  uploader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  institution TEXT NOT NULL,
  course TEXT NOT NULL,
  subject TEXT NOT NULL,
  semester TEXT DEFAULT '',
  grade TEXT DEFAULT '',
  year INT,
  exam_type TEXT NOT NULL DEFAULT 'other'
    CHECK (exam_type IN ('midterm','final','quiz','assignment','lab','practical','other')),
  custom_exam_type TEXT DEFAULT '',
  professor TEXT DEFAULT '',
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  is_public BOOLEAN NOT NULL DEFAULT true,
  file_url TEXT NOT NULL,
  file_size BIGINT DEFAULT 0,
  file_type TEXT DEFAULT '',
  thumbnail_url TEXT DEFAULT '',
  download_count INT NOT NULL DEFAULT 0,
  view_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_res_uploader ON public.resources(uploader_id);
CREATE INDEX idx_res_subject ON public.resources(subject);
CREATE INDEX idx_res_institution ON public.resources(institution);
CREATE INDEX idx_res_created ON public.resources(created_at DESC);
CREATE INDEX idx_res_downloads ON public.resources(download_count DESC);
CREATE INDEX idx_res_exam ON public.resources(exam_type);
CREATE INDEX idx_res_year ON public.resources(year);

ALTER TABLE public.resources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "res_select" ON public.resources FOR SELECT USING (is_public = true);
CREATE POLICY "res_insert" ON public.resources FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "res_update" ON public.resources FOR UPDATE USING (auth.uid() = uploader_id);
CREATE POLICY "res_delete" ON public.resources FOR DELETE USING (auth.uid() = uploader_id);

-- Full-text search vector
ALTER TABLE public.resources ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(description,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(subject,'')), 'A') ||
    setweight(to_tsvector('english', coalesce(institution,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(course,'')), 'B') ||
    setweight(to_tsvector('english', coalesce(professor,'')), 'C')
  ) STORED;
CREATE INDEX idx_res_search ON public.resources USING GIN(search_vector);

-- =========== TAGS ===========
CREATE TABLE public.tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT UNIQUE NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  resource_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_tags_slug ON public.tags(slug);
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tags_select" ON public.tags FOR SELECT USING (true);
CREATE POLICY "tags_insert" ON public.tags FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "tags_update" ON public.tags FOR UPDATE USING (auth.uid() IS NOT NULL);

-- =========== RESOURCE TAGS ===========
CREATE TABLE public.resource_tags (
  resource_id UUID REFERENCES public.resources(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (resource_id, tag_id)
);
ALTER TABLE public.resource_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rt_select" ON public.resource_tags FOR SELECT USING (true);
CREATE POLICY "rt_all" ON public.resource_tags FOR ALL USING (auth.uid() IS NOT NULL);

-- =========== COMMENTS ===========
CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  resource_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_edited BOOLEAN NOT NULL DEFAULT false,
  edited_at TIMESTAMPTZ,
  like_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_cmt_resource ON public.comments(resource_id);
CREATE INDEX idx_cmt_parent ON public.comments(parent_id);
CREATE INDEX idx_cmt_author ON public.comments(author_id);
CREATE INDEX idx_cmt_created ON public.comments(created_at DESC);
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cmt_select" ON public.comments FOR SELECT USING (true);
CREATE POLICY "cmt_insert" ON public.comments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "cmt_update" ON public.comments FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "cmt_delete" ON public.comments FOR DELETE USING (auth.uid() = author_id);

-- =========== COMMENT LIKES ===========
CREATE TABLE public.comment_likes (
  comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (comment_id, user_id)
);
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cl_select" ON public.comment_likes FOR SELECT USING (true);
CREATE POLICY "cl_all" ON public.comment_likes FOR ALL USING (auth.uid() IS NOT NULL);

-- =========== FOLLOWS ===========
CREATE TABLE public.follows (
  follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);
CREATE INDEX idx_follows_following ON public.follows(following_id);
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "follows_select" ON public.follows FOR SELECT USING (true);
CREATE POLICY "follows_all" ON public.follows FOR ALL USING (auth.uid() IS NOT NULL);

-- =========== SUBJECT FOLLOWS ===========
CREATE TABLE public.subject_follows (
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, subject)
);
ALTER TABLE public.subject_follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sf_select" ON public.subject_follows FOR SELECT USING (true);
CREATE POLICY "sf_all" ON public.subject_follows FOR ALL USING (auth.uid() IS NOT NULL);

-- =========== NOTIFICATIONS ===========
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('follow','comment','reply','comment_like','subject_upload')),
  resource_id UUID REFERENCES public.resources(id) ON DELETE SET NULL,
  comment_id UUID REFERENCES public.comments(id) ON DELETE SET NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notif_user ON public.notifications(user_id, created_at DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notif_select" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "notif_update" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- =========== STORAGE BUCKETS ===========
-- Run these in Supabase dashboard or via API:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('resources', 'resources', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
--
-- Storage RLS for resources bucket:
-- CREATE POLICY "storage_res_select" ON storage.objects FOR SELECT USING (bucket_id = 'resources');
-- CREATE POLICY "storage_res_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'resources' AND auth.uid() IS NOT NULL);
-- CREATE POLICY "storage_res_delete" ON storage.objects FOR DELETE USING (bucket_id = 'resources' AND auth.uid()::text = (storage.foldername(name))[1]);
--
-- Storage RLS for avatars bucket:
-- CREATE POLICY "storage_av_select" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
-- CREATE POLICY "storage_av_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid() IS NOT NULL);
-- CREATE POLICY "storage_av_delete" ON storage.objects FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =========== HELPER: update tag counts ===========
CREATE OR REPLACE FUNCTION public.update_tag_count(p_tag_id UUID)
RETURNS VOID AS $$ BEGIN
  UPDATE public.tags SET resource_count = (
    SELECT COUNT(*) FROM public.resource_tags WHERE tag_id = p_tag_id
  ) WHERE id = p_tag_id;
END;
 $$ LANGUAGE plpgsql;
