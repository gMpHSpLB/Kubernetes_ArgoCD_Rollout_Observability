# Add logging setup in mylearning tests
# Note:
# This guarantees every pytest worker process for mylearning 
# initializes your logging config. Without this, your 
# logger = logging.getLogger(__name__) in fibonacci.py 
# will log with default handlers, and pytest’s CLI logging may not show it.
from exercises.logging_config import setup_logging

def pytest_configure(config) -> None:
    setup_logging()