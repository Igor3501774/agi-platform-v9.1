from typing import Dict, Type, List
from abc import ABC, abstractmethod

class BaseAgent(ABC):
    @abstractmethod
    async def run(self, task: str, context: dict) -> dict:
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        pass

class AgentFactory:
    _registry: Dict[str, Type[BaseAgent]] = {}

    @classmethod
    def register(cls, name: str):
        def decorator(agent_cls: Type[BaseAgent]):
            cls._registry[name] = agent_cls
            return agent_cls
        return decorator

    @classmethod
    def create(cls, name: str, **kwargs) -> BaseAgent:
        agent_cls = cls._registry.get(name)
        if not agent_cls:
            raise ValueError(f"Agent '{name}' not found in registry")
        return agent_cls(**kwargs)

    @classmethod
    def list_available(cls) -> List[str]:
        return list(cls._registry.keys())
