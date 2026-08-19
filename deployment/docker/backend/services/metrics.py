import time
from collections import defaultdict
from typing import Dict, Any

class Metrics:
    def __init__(self):
        self.request_count = defaultdict(int)
        self.error_count = defaultdict(int)
        self.response_times = defaultdict(list)
        self.start_time = time.time()
    
    def track_request(self, endpoint: str, status_code: int, duration: float):
        self.request_count[endpoint] += 1
        if status_code >= 400:
            self.error_count[endpoint] += 1
        self.response_times[endpoint].append(duration)
        if len(self.response_times[endpoint]) > 1000:
            self.response_times[endpoint] = self.response_times[endpoint][-1000:]
    
    def get_metrics(self) -> Dict[str, Any]:
        metrics = {
            "uptime": time.time() - self.start_time,
            "total_requests": sum(self.request_count.values()),
            "total_errors": sum(self.error_count.values()),
        }
        for endpoint, times in self.response_times.items():
            if times:
                metrics[f"{endpoint}_avg_ms"] = round(sum(times) / len(times) * 1000, 2)
                metrics[f"{endpoint}_count"] = len(times)
        return metrics

metrics = Metrics()