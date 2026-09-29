from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register("hubs", views.HubViewSet)
router.register("posts", views.PostViewSet)
router.register("comments", views.CommentViewSet)
router.register("polls", views.PollViewSet)
router.register("quizzes", views.QuizViewSet)
router.register("flashcards", views.FlashcardViewSet)
router.register("chat-rooms", views.ChatRoomViewSet, basename="chatroom")
router.register("messages", views.MessageViewSet)
router.register("badges", views.BadgeViewSet)
router.register("notifications", views.NotificationViewSet, basename="notification")

urlpatterns = [
    path("auth/register/", views.RegisterView.as_view()),
    path("auth/login/", views.LoginView.as_view()),
    path("auth/me/", views.MeView.as_view()),
    path("polls/options/<int:option_id>/vote/", views.PollVoteView.as_view()),
    path("", include(router.urls)),
]
