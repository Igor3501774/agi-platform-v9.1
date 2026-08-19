from sqlalchemy import Column, String, Boolean, DateTime, Float, Integer, Text, JSON, ForeignKey, Index, UUID as PGUUID
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
import uuid
from .base import Base

class UserModel(Base):
    __tablename__ = "users"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, index=True, nullable=False)
    name = Column(String(100))
    phone = Column(String(20))
    plan = Column(String(20), default="free")
    preferences = Column(JSON, default=dict)
    is_active = Column(Boolean, default=True)
    last_login = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class AgentModel(Base):
    __tablename__ = "agents"
    id = Column(String(50), primary_key=True)
    name = Column(String(100), nullable=False)
    specialty = Column(String(100), nullable=False)
    description = Column(Text)
    icon = Column(String(10))
    category = Column(String(50))
    capabilities = Column(JSON, default=list)
    is_premium = Column(Boolean, default=False)
    is_safe = Column(Boolean, default=False)
    prompt_template = Column(Text)
    knowledge_base = Column(JSON, default=list)
    tools = Column(JSON, default=list)
    extra_data = Column(JSON, default=dict)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class ConversationModel(Base):
    __tablename__ = "conversations"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id"))
    agent_id = Column(String(50), ForeignKey("agents.id"))
    title = Column(String(255))
    extra_data = Column(JSON, default=dict)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

class MessageModel(Base):
    __tablename__ = "messages"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conversation_id = Column(PGUUID(as_uuid=True), ForeignKey("conversations.id"))
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id"))
    agent_id = Column(String(50), ForeignKey("agents.id"))
    content = Column(Text, nullable=False)
    is_user = Column(Boolean, nullable=False)
    extra_data = Column(JSON, default=dict)
    parent_id = Column(PGUUID(as_uuid=True), ForeignKey("messages.id"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

class MemoryModel(Base):
    __tablename__ = "memories"
    id = Column(String(64), primary_key=True)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id"))
    agent_id = Column(String(50), ForeignKey("agents.id"), nullable=True)
    content = Column(Text, nullable=False)
    context = Column(String(100))
    importance = Column(Float, default=0.5)
    extra_data = Column(JSON, default=dict)
    expires_at = Column(DateTime)
    created_at = Column(DateTime, server_default=func.now())

class SessionModel(Base):
    __tablename__ = "sessions"
    id = Column(String(36), primary_key=True)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    device = Column(String(100))
    ip = Column(String(45))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    expires_at = Column(DateTime)
    last_activity = Column(DateTime, server_default=func.now())

class AuditModel(Base):
    __tablename__ = "audits"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id"))
    action = Column(String(50), nullable=False)
    resource = Column(String(50))
    resource_id = Column(String(50))
    extra_data = Column(JSON, default=dict)
    ip = Column(String(45))
    user_agent = Column(Text)
    created_at = Column(DateTime, server_default=func.now())

class CostTrackingModel(Base):
    __tablename__ = "cost_tracking"
    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id"))
    agent_id = Column(String(50), ForeignKey("agents.id"))
    provider = Column(String(50))
    model = Column(String(50))
    tokens = Column(Integer)
    cost = Column(Float)
    latency = Column(Float)
    created_at = Column(DateTime, server_default=func.now())

# Индексы
Index("idx_messages_conversation", MessageModel.conversation_id)
Index("idx_messages_user", MessageModel.user_id)
Index("idx_messages_created", MessageModel.created_at)
Index("idx_memories_user", MemoryModel.user_id)
Index("idx_memories_context", MemoryModel.context)
Index("idx_sessions_user", SessionModel.user_id)
Index("idx_audits_user", AuditModel.user_id)
Index("idx_audits_action", AuditModel.action)
Index("idx_cost_user", CostTrackingModel.user_id)
Index("idx_cost_created", CostTrackingModel.created_at)
