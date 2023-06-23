from typing import Union
from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.openapi.utils import get_openapi
from starlette.status import HTTP_403_FORBIDDEN
from starlette.middleware.cors import CORSMiddleware
from fastapi.security.api_key import APIKeyHeader, APIKey
from fastapi import Security, Depends, FastAPI, HTTPException, Path

app = FastAPI(title="Casia")


def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title="Casia Microservices",
        version="0.0.1",
        description="Welcome to Casia Microservices, your AI botnist",
        routes=app.routes,
    )
    openapi_schema["info"]["x-logo"] = {
        "url": "https://picsum.photos/id/107/200/300.jpg"
    }
    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = "this is the token"
API_KEY_NAME = "api_token"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)


async def get_api_key(
    api_key_header: str = Security(api_key_header)
):

    if api_key_header == API_KEY:
        return api_key_header
    else:
        raise HTTPException(
            status_code=HTTP_403_FORBIDDEN, detail="Could not validate credentials"
        )


class Message(BaseModel):
    message: str = "Hello from Casia AI Microservice API"


class Answer(BaseModel):
    answer: str


@app.get("/", response_model=Message)
def read_root():
    return {"message": "Hello from Casia AI Microservice API"}


@app.get("/casia/ask/{model}/{user_question}", response_model=Answer, description="", response_description="", response_model_exclude_unset=True)
async def askcasia(model: str, user_question: str, api_key: APIKey = Depends(get_api_key)):
    return {
        "answer": f"your answer, {model}, {user_question}"
    }
