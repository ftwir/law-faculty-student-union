from django.contrib.auth import authenticate
from rest_framework import viewsets, generics, status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import models, serializers
from .permissions import IsAdminOrAgent, ReadOnlyForVisitors


class RegisterView(generics.CreateAPIView):
    permission_classes = [AllowAny]
    serializer_class = serializers.RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        token, _ = Token.objects.get_or_create(user=profile.user)
        return Response(
            {"token": token.key, "profile": serializers.UserProfileSerializer(profile).data},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get("username")
        password = request.data.get("password")
        user = authenticate(username=username, password=password)
        if not user:
            return Response({"detail": "بيانات الدخول غير صحيحة"}, status=status.HTTP_401_UNAUTHORIZED)
        token, _ = Token.objects.get_or_create(user=user)
        profile = getattr(user, "profile", None)
        return Response({
            "token": token.key,
            "profile": serializers.UserProfileSerializer(profile).data if profile else None,
        })


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = getattr(request.user, "profile", None)
        if not profile:
            return Response({"detail": "لا يوجد ملف شخصي"}, status=404)
        return Response(serializers.UserProfileSerializer(profile).data)


class HubViewSet(viewsets.ModelViewSet):
    queryset = models.Hub.objects.all().order_by("-created_at")
    serializer_class = serializers.HubSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user.profile)


class PostViewSet(viewsets.ModelViewSet):
    queryset = models.Post.objects.all().order_by("-created_at")
    serializer_class = serializers.PostSerializer
    permission_classes = [ReadOnlyForVisitors]

    def get_queryset(self):
        qs = super().get_queryset()
        hub_id = self.request.query_params.get("hub")
        if hub_id:
            qs = qs.filter(hub_id=hub_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(author=self.request.user.profile)


class CommentViewSet(viewsets.ModelViewSet):
    queryset = models.Comment.objects.all().order_by("created_at")
    serializer_class = serializers.CommentSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        serializer.save(author=self.request.user.profile)


class PollViewSet(viewsets.ModelViewSet):
    queryset = models.Poll.objects.all()
    serializer_class = serializers.PollSerializer
    permission_classes = [ReadOnlyForVisitors]


class PollVoteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, option_id):
        option = models.PollOption.objects.get(pk=option_id)
        vote, created = models.PollVote.objects.get_or_create(
            option=option, user=request.user.profile
        )
        if not created:
            return Response({"detail": "لقد صوّتّ بالفعل"}, status=400)
        return Response({"detail": "تم التصويت"}, status=201)


class QuizViewSet(viewsets.ModelViewSet):
    queryset = models.Quiz.objects.all()
    serializer_class = serializers.QuizSerializer
    permission_classes = [ReadOnlyForVisitors]


class FlashcardViewSet(viewsets.ModelViewSet):
    queryset = models.Flashcard.objects.all()
    serializer_class = serializers.FlashcardSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user.profile)


class ChatRoomViewSet(viewsets.ModelViewSet):
    queryset = models.ChatRoom.objects.all()
    serializer_class = serializers.ChatRoomSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return models.ChatRoom.objects.filter(participants__user=self.request.user.profile)


class MessageViewSet(viewsets.ModelViewSet):
    queryset = models.Message.objects.all().order_by("sent_at")
    serializer_class = serializers.MessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        room_id = self.request.query_params.get("room")
        if room_id:
            qs = qs.filter(room_id=room_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(sender=self.request.user.profile)


class BadgeViewSet(viewsets.ModelViewSet):
    queryset = models.Badge.objects.all()
    serializer_class = serializers.BadgeSerializer
    permission_classes = [IsAdminOrAgent]


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = serializers.NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return models.Notification.objects.filter(recipient=self.request.user.profile)
