from django.contrib.auth import authenticate
from django.db import transaction
from django.utils import timezone

from rest_framework import viewsets, generics, status, permissions\nfrom rest_framework.decorators import action
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import PermissionDenied

from . import models, serializers
from .permissions import IsAdminOrAgent, IsAgent, ReadOnlyForVisitors


class HealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response({
            "ok": True,
            "service": "law-faculty-student-union-backend",
        })


class RegisterView(generics.CreateAPIView):
    permission_classes = [AllowAny]
    serializer_class = serializers.RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            profile = serializer.save()
        except Exception as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        token, _ = Token.objects.get_or_create(user=profile.user)

        return Response(
            {
                "token": token.key,
                "profile": serializers.UserProfileSerializer(profile).data,
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = str(request.data.get("username", "")).strip()
        password = request.data.get("password", "")

        if not username or not password:
            return Response(
                {"detail": "اسم المستخدم وكلمة المرور مطلوبان."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = authenticate(
            request=request,
            username=username,
            password=password,
        )

        if not user:
            return Response(
                {"detail": "بيانات الدخول غير صحيحة."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.is_active:
            return Response(
                {"detail": "هذا الحساب غير مفعل."},
                status=status.HTTP_403_FORBIDDEN,
            )

        profile = getattr(user, "profile", None)

        if profile is None:
            return Response(
                {"detail": "الحساب لا يحتوي على ملف شخصي."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        token, _ = Token.objects.get_or_create(user=user)

        return Response({
            "token": token.key,
            "profile": serializers.UserProfileSerializer(profile).data,
        })


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = getattr(request.user, "profile", None)

        if not profile:
            return Response(
                {"detail": "لا يوجد ملف شخصي لهذا الحساب."},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            serializers.UserProfileSerializer(profile).data
        )


class HubViewSet(viewsets.ModelViewSet):
    queryset = models.Hub.objects.all().order_by("-created_at")
    serializer_class = serializers.HubSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        serializer.save(
            created_by=self.request.user.profile
        )


class PostViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Post.objects
        .select_related("hub", "author")
        .prefetch_related("comments", "poll", "quiz")
        .order_by("-created_at")
    )
    serializer_class = serializers.PostSerializer
    permission_classes = [ReadOnlyForVisitors]

    def get_queryset(self):
        queryset = super().get_queryset()

        hub_id = self.request.query_params.get("hub")

        if hub_id:
            queryset = queryset.filter(hub_id=hub_id)

        return queryset


    def perform_create(self, serializer):
        serializer.save(
            author=self.request.user.profile
        )


class CommentViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Comment.objects
        .select_related("post", "author")
        .order_by("created_at")
    )
    serializer_class = serializers.CommentSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        serializer.save(
            author=self.request.user.profile
        )


class PollViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Poll.objects
        .select_related("post")
        .prefetch_related("options__votes")
    )
    serializer_class = serializers.PollSerializer
    permission_classes = [ReadOnlyForVisitors]


class PollVoteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, option_id):
        profile = getattr(request.user, "profile", None)

        if profile is None:
            return Response(
                {"detail": "لا يوجد ملف شخصي."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        option = models.PollOption.objects.filter(
            pk=option_id
        ).select_related("poll").first()

        if option is None:
            return Response(
                {"detail": "خيار التصويت غير موجود."},
                status=status.HTTP_404_NOT_FOUND,
            )

        poll = option.poll

        if poll.closes_at and timezone.now() >= poll.closes_at:
            return Response(
                {"detail": "انتهى التصويت في هذا الاستطلاع."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        already_voted = models.PollVote.objects.filter(
            option__poll=poll,
            user=profile,
        ).exists()

        if already_voted:
            return Response(
                {"detail": "لقد قمت بالتصويت في هذا الاستطلاع بالفعل."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        vote = models.PollVote.objects.create(
            option=option,
            user=profile,
        )

        return Response(
            {
                "id": vote.id,
                "poll": poll.id,
                "option": option.id,
                "user": profile.id,
            },
            status=status.HTTP_201_CREATED,
        )


class QuizViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Quiz.objects
        .prefetch_related("questions")
        .all()
    )
    serializer_class = serializers.QuizSerializer
    permission_classes = [ReadOnlyForVisitors]


class FlashcardViewSet(viewsets.ModelViewSet):
    queryset = models.Flashcard.objects.all()
    serializer_class = serializers.FlashcardSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        serializer.save(
            created_by=self.request.user.profile
        )


class ChatRoomViewSet(viewsets.ModelViewSet):
    serializer_class = serializers.ChatRoomSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = getattr(self.request.user, "profile", None)

        if profile is None:
            return models.ChatRoom.objects.none()

        return (
            models.ChatRoom.objects
            .filter(participants__user=profile)
            .distinct()
            .order_by("-created_at")
        )

    @transaction.atomic
    def perform_create(self, serializer):
        profile = self.request.user.profile

        room = serializer.save()

        models.ChatParticipant.objects.get_or_create(
            room=room,
            user=profile,
        )


class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = serializers.MessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = getattr(self.request.user, "profile", None)

        if profile is None:
            return models.Message.objects.none()

        queryset = (
            models.Message.objects
            .filter(room__participants__user=profile)
            .select_related("sender", "room")
            .order_by("sent_at")
            .distinct()
        )

        room_id = self.request.query_params.get("room")

        if room_id:
            queryset = queryset.filter(room_id=room_id)

        return queryset

    def perform_create(self, serializer):
        profile = self.request.user.profile
        room = serializer.validated_data["room"]

        participant = models.ChatParticipant.objects.filter(
            room=room,
            user=profile,
        ).exists()

        if not participant:
            raise PermissionDenied(
                "You are not a participant in this chat room."
            )

        serializer.save(
            sender=profile
        )


class BadgeViewSet(viewsets.ModelViewSet):
    queryset = models.Badge.objects.all()
    serializer_class = serializers.BadgeSerializer
    permission_classes = [IsAdminOrAgent]


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = serializers.NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = getattr(self.request.user, "profile", None)

        if profile is None:
            return models.Notification.objects.none()

        return (
            models.Notification.objects
            .filter(recipient=profile)
            .order_by("-created_at")
        )
