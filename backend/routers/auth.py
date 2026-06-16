from fastapi import APIRouter,HTTPException
from pydantic import BaseModel
from services.auth_service import AuthService

router=APIRouter(
    prefix="/auth",
    tags=["Authentication"]

)
class VerifyRequest(BaseModel):
    token:str

class RegisterRequest(BaseModel):
    token:str
    business_name:str
    instagram_handle:str

@router.get("/test")
def test_auth():
    return {
        "message":"Auth router is working"
    }

@router.post("/verify")

def verify_token(payload:VerifyRequest):
    result=AuthService.verify_supabase_token(payload.token)
    if not result['success']:
        raise HTTPException(status_code=401,detail="Invalid token: {result['error]}")
    return{
        'authenticcated':True,
        'user_id':result['user'].id,
        'email':result['user'].email
    }
@router.post("/register")
def register_user(payload: RegisterRequest):
    result=AuthService.register_new_user(
        token=payload.token,
        business_name=payload.business_name,
        instagram_handle=payload.instagram_handle
    )
    if not result['success']:
        raise HTTPException(status_code=400,detail=f"Registration failed: {result['error']}")
    return{
        "registered":True,
        "user_id":result["user_id"],
        "message":result["message"]
    }