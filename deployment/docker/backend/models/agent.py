from pydantic import BaseModel
from typing import Optional, List

class Agent(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    specialty: Optional[str] = None
    category: str = "general"
    is_premium: bool = False
    is_safe: bool = False
    icon: str = "🤖"
    prompt_template: Optional[str] = None
    tags: List[str] = []