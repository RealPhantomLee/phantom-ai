"""FastAPI orchestrator entrypoint."""

from fastapi import FastAPI

app = FastAPI(title="phantom-ai", version="0.1.0")


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


@app.get("/api/v1/status")
async def status():
    """Get system status."""
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
