from supabase import create_client, Client
from core.config import settings

# Instead of raw os.getenv, we use the validated variables from your config file
SUPABASE_URL = settings.SUPABASE_URL
SUPABASE_SECRET_KEY = settings.SUPABASE_SECRET_KEY

# Initialize the official cloud client connection
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SECRET_KEY)