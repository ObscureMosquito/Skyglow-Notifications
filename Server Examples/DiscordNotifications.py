import asyncio
import websockets
import json
import aiohttp  # Import the aiohttp library for async HTTP requests

DISCORD_GATEWAY = "wss://gateway.discord.gg/?v=9&encoding=json"
DISCORD_TOKEN = ""

async def discord_communicator():
    bot_user_id = None
    async with websockets.connect(DISCORD_GATEWAY) as websocket, aiohttp.ClientSession() as session:
        intents = 512 + 4096  # GUILD_MESSAGES and DIRECT_MESSAGES
        await websocket.send(json.dumps({
            "op": 2,
            "d": {
                "token": DISCORD_TOKEN,
                "intents": intents,
                "properties": {
                    "$os": "linux",
                    "$browser": "my_discord_client",
                    "$device": "my_discord_client"
                }
            }
        }))

        async def send_heartbeat(interval):
            while True:
                await asyncio.sleep(interval / 1000)
                await websocket.send(json.dumps({"op": 1, "d": None}))

        while True:
            try:
                message = await websocket.recv()
                message_data = json.loads(message)
                if message_data.get("op") == 10:  # Hello
                    heartbeat_interval = message_data["d"]["heartbeat_interval"]
                    asyncio.create_task(send_heartbeat(heartbeat_interval))
                elif message_data.get("t") == "READY":  # Ready
                    bot_user_id = message_data["d"]["user"]["id"]
                elif message_data.get("t") == "MESSAGE_CREATE":  # Message
                    author_id = message_data["d"]["author"]["id"]
                    if author_id != bot_user_id:  # Ignore bot's own messages
                        author_name = message_data["d"]["author"]["username"]
                        content = message_data["d"]["content"].strip()
                        channel_id = message_data["d"]["channel_id"]
                        if content:
                            # Prepare the JSON payload for the HTTP POST request
                            payload = {
                                "sender": author_name,
                                "message": content,
                                "topic": "com.Trevir.Discord",
                                "extra": {
                                    "channelId": channel_id,
                                    "priority": "high"
                                }
                            }
                            # Perform the asynchronous HTTP POST request
                            async with session.post('http://localhost:5000/send_data', json=payload) as response:
                                if response.status == 200:
                                    print(f"Successfully sent message to server from {author_name}")
                                else:
                                    print(f"Failed to send message to server from {author_name}, Response Status: {response.status}")
            except websockets.ConnectionClosed:
                print("Websocket connection closed. Reconnecting...")
                await asyncio.sleep(1)
                return await discord_communicator()

async def main():
    while True:
        try:
            await discord_communicator()
        except Exception as e:
            print(f"An error occurred: {e}")
            print("Attempting to restart discord_communicator...")
            await asyncio.sleep(10)  # Wait for 10 seconds before restarting

# Run the main coroutine indefinitely
if __name__ == "__main__":
    asyncio.run(main())
