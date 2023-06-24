import os
import json
from . import functions
from fastapi import FastAPI
from typing import Annotated
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

cohere_key = json.loads(functions.get_secret("cohere_api_key"))[
    "cohere_api_key"]
openai_key = json.loads(functions.get_secret("openai_key"))["openai_api_key"]
vdb_key = json.loads(functions.get_secret("pinecone_key"))[
    "pinecone_client_key"]
API_KEY = json.loads(functions.get_secret("casia_api_token"))["api_token"]

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
    ai_provider: str
    model: str
    answer: str


@app.get("/", response_model=Message)
def read_root():
    return {"message": "Hello from Casia AI Microservice API"}


@app.post("/casia/ask/openai/{model}/{user_question}",
          response_model=Answer,
          description="",
          response_description="")
async def askopenai(model: str, user_question: str, api_key: APIKey = Depends(get_api_key)):
    answer = functions.openai_interface(
        user_question, model, openai_key, vdb_key)
    return {
        "ai_provider": "cohere",
        "model": model,
        "answer": answer
    }


@app.post("/casia/ask/cohere/{model}/{user_question}",
          response_model=Answer,
          description="Cohere Interface",
          response_description="This endpoint provide an interfact to interact with cohere ai models",
          response_model_exclude_unset=True)
async def askcohere(user_question: Annotated[str, Path(..., description="user chat query")],
                    model: Annotated[str, Path("command",
                                               description="The model to use for this question, it can only be command (default) or command-light")],
                    api_key: APIKey = Depends(get_api_key)):
    if len(user_question.split()) < 5:
        answer = functions.cohere_interface(
            user_question, model, cohere_key, vdb_key, openai_key)
        return {
            "ai_provider": "cohere",
            "model": model,
            "answer": answer
        }
    else:
        model = "gpt-3.5-turbo-16k"
        answer = functions.openai_interface(
            user_question, model, openai_key, vdb_key)
        return {
            "ai_provider": "openai",
            "model": model,
            "answer": answer
        }
