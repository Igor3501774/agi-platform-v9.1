def count_tokens(text: str) -> int:
    if not text:
        return 0
    return len(text) // 4
