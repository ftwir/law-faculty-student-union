from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser
from rest_framework.authtoken.models import Token


class TokenAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        query_string = scope.get("query_string", b"").decode()
        params = parse_qs(query_string)
        token_key = params.get("token", [None])[0]
        scope["user"] = await self._get_user(token_key)
        return await super().__call__(scope, receive, send)

    @database_sync_to_async
    def _get_user(self, token_key):
        if not token_key:
            return AnonymousUser()
        try:
            return Token.objects.select_related("user").get(key=token_key).user
        except Token.DoesNotExist:
            return AnonymousUser()
