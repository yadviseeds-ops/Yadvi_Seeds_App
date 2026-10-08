import asyncio
import logging
from app.main import app

logging.basicConfig(level=logging.INFO)

async def test_startup():
    print("Testing startup...")
    for handler in app.router.on_startup:
        if asyncio.iscoroutinefunction(handler):
            await handler()
        else:
            handler()
    print("Startup tested successfully.")

if __name__ == "__main__":
    asyncio.run(test_startup())
