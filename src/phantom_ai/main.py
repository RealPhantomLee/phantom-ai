"""FastAPI orchestrator entrypoint."""

from fastapi import Depends, FastAPI, Header, HTTPException

from phantom_ai.config import settings

app = FastAPI(title="phantom-ai", version="0.1.0")


async def require_api_key(x_api_key: str = Header(default="")) -> None:
    if settings.api_key and x_api_key != settings.api_key:
        raise HTTPException(status_code=403, detail="Forbidden")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.get("/api/v1/status", dependencies=[Depends(require_api_key)])
async def status() -> dict:
    return {
        "orchestrator": "running",
        "voice": "ready",
        "vision": "ready",
        "gimbal": "ready",
        "k8s_agent": "ready",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
