from typing import Optional
from sqlmodel import Field, SQLModel
from datetime import datetime


class Chats(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    created_at_utc: datetime = Field(default_factory=datetime.utcnow)
    model: str
    question_length: int
    question_text: str
    answer_text: str
    processing_time_seconds: float
    endpoint_name: str


class Posts(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    created_at: datetime
    title: str
    short_description: str
    description: str
    image_s3_uri: str
