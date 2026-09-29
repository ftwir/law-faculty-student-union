from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer

from . import models


class ChatConsumer(AsyncJsonWebsocketConsumer):

    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        self.group_name = f"chat_{self.room_id}"

        user = self.scope["user"]

        if not user.is_authenticated:
            await self.close(code=4001)
            return

        if not await self._can_access_room():
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name,
        )

        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name,
        )

    async def receive_json(self, content, **kwargs):
        body = str(
            content.get("message", "")
        ).strip()

        if not body:
            return

        saved = await self._save_message(body)

        if saved is None:
            return

        await self.channel_layer.group_send(
            self.group_name,
            {
                "type": "chat.message",
                "message": saved["body"],
                "sender": saved["sender"],
                "sender_name": saved["sender_name"],
                "sent_at": saved["sent_at"],
            },
        )

    async def chat_message(self, event):
        await self.send_json({
            "message": event["message"],
            "sender": event["sender"],
            "sender_name": event["sender_name"],
            "sent_at": event["sent_at"],
        })

    @database_sync_to_async
    def _can_access_room(self):
        profile = getattr(
            self.scope["user"],
            "profile",
            None,
        )

        if profile is None:
            return False

        return models.ChatParticipant.objects.filter(
            room_id=self.room_id,
            user=profile,
        ).exists()

    @database_sync_to_async
    def _save_message(self, body):
        profile = getattr(
            self.scope["user"],
            "profile",
            None,
        )

        if profile is None:
            return None

        room = (
            models.ChatRoom.objects
            .filter(id=self.room_id)
            .first()
        )

        if room is None:
            return None

        participant = models.ChatParticipant.objects.filter(
            room=room,
            user=profile,
        ).exists()

        if not participant:
            return None

        message = models.Message.objects.create(
            room=room,
            sender=profile,
            body=body,
        )

        return {
            "body": message.body,
            "sender": profile.id,
            "sender_name": (
                profile.display_name
                or profile.user.username
            ),
            "sent_at": message.sent_at.isoformat(),
        }
