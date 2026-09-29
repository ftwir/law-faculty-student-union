import json

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer

from . import models


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        self.group_name = f"chat_{self.room_id}"

        if not self.scope["user"].is_authenticated:
            await self.close()
            return

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        body = data.get("body", "").strip()
        if not body:
            return

        message = await self._save_message(body)

        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "chat_message",
                "message": {
                    "id": message.id,
                    "body": message.body,
                    "sender_id": message.sender_id,
                    "sender_name": message.sender.display_name,
                    "sent_at": message.sent_at.isoformat(),
                },
            },
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps(event["message"]))

    @database_sync_to_async
    def _save_message(self, body):
        profile = self.scope["user"].profile
        room = models.ChatRoom.objects.get(pk=self.room_id)
        return models.Message.objects.create(room=room, sender=profile, body=body)
