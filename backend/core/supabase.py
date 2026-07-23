from supabase import Client, create_client

from core.config import settings


SUPABASE_URL = settings.SUPABASE_URL
SUPABASE_SECRET_KEY = settings.SUPABASE_SECRET_KEY
SUPABASE_ANON_KEY = settings.SUPABASE_ANON_KEY

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY,
)

supabase_admin: Client = supabase

supabase_anon: Client | None = (
    create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
    if SUPABASE_ANON_KEY
    else None
)