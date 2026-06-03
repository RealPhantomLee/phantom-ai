"""Configuration management via Pydantic and environment variables."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Core application settings."""

    # Ollama
    ollama_base_url: str = "http://ollama.phantom-ai.svc:11434"
    ollama_model: str = "llama3.1:8b"

    # Voice
    audio_input_device: str = "BlueDragon"
    audio_output_device: str = "default"
    whisper_model: str = "distil-large-v3"
    openwakeword_model: str = "alexa"
    piper_voice: str = "en_US-lessac-medium"

    # Vision
    camera_device: str = "/dev/video0"
    yolo_model: str = "yolov8n"
    edge_vision_url: str = "http://aipi-vision.phantom-ai.svc:8000"

    # Gimbal
    gimbal_ble_address: str = "FC:58:FA:XX:XX:XX"
    gimbal_pan_limit: int = 270
    gimbal_tilt_limit: int = 45
    gimbal_velocity_limit: int = 90

    # K8s
    kubernetes_service_host: str = "kubernetes.default.svc"
    kubernetes_service_port: int = 443
    k8s_approval_ttl: int = 300
    k8s_write_namespaces: str = "default,local-ai,vaultkeeper,phantom-ai"

    # Notifications
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    report_schedule: str = "0 18 * * *"
    report_timezone: str = "America/Chicago"

    # RAG
    rag_vector_db_url: str = "http://chromadb.phantom-ai.svc:8000"
    rag_chunk_size: int = 1000
    rag_overlap: int = 100

    # Redis
    redis_url: str = "redis://redis.phantom-ai.svc:6379"
    redis_db: int = 0

    # API security
    api_key: str = ""

    # Logging
    log_level: str = "INFO"
    debug: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
