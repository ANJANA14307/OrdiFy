from core.supabase import supabase

class AuthService:
    @staticmethod
    def verify_supabase_token(token:str):
        try:
            #we ask supabase if the user digital token is valid orr not
            response=supabase.auth.get_user(token)
            return{
                "success":True,
                "user":response.user
            }
        except Exception as e:
            return{
                "success":False,
                "error":str(e)
            }
    @staticmethod
    def register_new_user(token:str, business_name:str, instagram_handle:str):
        try:
            user_response=supabase.auth.get_user(token)
            user=user_response.user
            
            profile_data={
                "id":user.id,
                "email":user.email,
                "business_name":business_name,
                "instagram_handle":instagram_handle,
                "plan_tier":"free"

            }
            supabase.table("users").insert(profile_data).execute()
            return{
                "success":True,
                "user_id":user.id,
                "message":"User profile registered successfully"}
        except Exception as e:
            return{
                "success":False,
                "error":str(e)
            }