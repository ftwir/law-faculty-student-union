import os

from django.core.asgi import get_asgi_application

from core.ws_auth import TokenAuthMiddleware
from channels.routing import ProtocolTypeRouter, URLRouter


os.environ.setdefault(
    "DJANGO_SETTINGS_MODULE",
    "config.settings",
)


django_asgi_app = get_asgi_application()


import core.routing  # noqa: E402


application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,

        "websocket": AuthMiddlewareStack(
            URLRouter(
                core.routing.websocket_urlpatterns
            )
        ),
    }
)
