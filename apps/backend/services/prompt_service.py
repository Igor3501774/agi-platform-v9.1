import yaml
from pathlib import Path
from typing import Dict, Any, Optional
from config.logger import logger

class PromptService:
    def __init__(self, prompts_dir: str = "prompts"):
        self.prompts_dir = Path(prompts_dir)
        self._prompts: Dict[str, Dict] = {}
        self._load_all()
    
    def _load_all(self):
        if not self.prompts_dir.exists():
            logger.warning(f"Prompts directory not found: {self.prompts_dir}")
            return
        for file in self.prompts_dir.glob("**/*.yaml"):
            try:
                with open(file, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f)
                    name = file.stem
                    self._prompts[name] = data
            except Exception as e:
                logger.error(f"Failed to load prompt {file}: {e}")
        logger.info(f"Loaded {len(self._prompts)} prompts")
    
    def get_prompt(self, name: str) -> Optional[str]:
        data = self._prompts.get(name, {})
        return data.get("system", "")
