from django.contrib.auth import authenticate
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from rest_framework import viewsets, generics, status, permissions
from rest_framework.decorators import action
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

    def patch(self, request):
        profile = getattr(request.user, "profile", None)

        if not profile:
            return Response(
                {"detail": "لا يوجد ملف شخصي لهذا الحساب."},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = serializers.UserProfileSerializer(
            profile,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(serializer.data)


class HubViewSet(viewsets.ModelViewSet):
    queryset = models.Hub.objects.select_related("hub_admin", "created_by").all().order_by("id")
    serializer_class = serializers.HubSerializer
    permission_classes = [ReadOnlyForVisitors]

    def perform_create(self, serializer):
        profile = self.request.user.profile
        if profile.role != models.Role.AGENT:
            raise PermissionDenied("Only the Agent can create hubs.")
        serializer.save(created_by=profile, hub_admin=profile, is_public=False)

    def _can_manage(self, profile, hub):
        return bool(profile and (profile.role == models.Role.AGENT or hub.hub_admin_id == profile.id))

    @action(detail=True, methods=["post"], permission_classes=[IsAuthenticated])
    def request_membership(self, request, pk=None):
        hub = self.get_object()
        profile = request.user.profile
        membership, _ = models.HubMembership.objects.get_or_create(
            hub=hub, user=profile,
            defaults={"status": models.HubMembershipStatus.PENDING},
        )
        if membership.status == models.HubMembershipStatus.APPROVED:
            return Response({"status": "approved"})
        membership.status = models.HubMembershipStatus.PENDING
        membership.save(update_fields=["status"])
        return Response({"status": "pending"}, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["get"], permission_classes=[IsAuthenticated])
    def membership_requests(self, request, pk=None):
        hub = self.get_object()
        if not self._can_manage(request.user.profile, hub):
            raise PermissionDenied("Only the hub administrator can manage membership requests.")
        queryset = hub.memberships.filter(
            status=models.HubMembershipStatus.PENDING
        ).select_related("user").order_by("joined_at")
        return Response(serializers.HubMembershipSerializer(queryset, many=True).data)

    @action(detail=True, methods=["post"], permission_classes=[IsAuthenticated])
    def approve_member(self, request, pk=None):
        hub = self.get_object()
        if not self._can_manage(request.user.profile, hub):
            raise PermissionDenied("Only the hub administrator can approve members.")
        membership = hub.memberships.filter(
            user_id=request.data.get("user_id"),
            status=models.HubMembershipStatus.PENDING,
        ).first()
        if not membership:
            return Response({"detail": "طلب العضوية غير موجود."}, status=status.HTTP_404_NOT_FOUND)
        membership.status = models.HubMembershipStatus.APPROVED
        membership.save(update_fields=["status"])
        return Response(serializers.HubMembershipSerializer(membership).data)

    @action(detail=True, methods=["post"], permission_classes=[IsAuthenticated])
    def reject_member(self, request, pk=None):
        hub = self.get_object()
        if not self._can_manage(request.user.profile, hub):
            raise PermissionDenied("Only the hub administrator can reject members.")
        membership = hub.memberships.filter(user_id=request.data.get("user_id")).first()
        if not membership:
            return Response({"detail": "عضوية المستخدم غير موجودة."}, status=status.HTTP_404_NOT_FOUND)
        membership.status = models.HubMembershipStatus.REJECTED
        membership.save(update_fields=["status"])
        return Response(serializers.HubMembershipSerializer(membership).data)

    @action(detail=True, methods=["post"], permission_classes=[IsAuthenticated])
    def set_admin(self, request, pk=None):
        hub = self.get_object()
        if request.user.profile.role != models.Role.AGENT:
            raise PermissionDenied("Only the Agent can assign hub administrators.")
        admin_profile = models.User.objects.filter(
            id=request.data.get("user_id"), role=models.Role.ADMIN
        ).first()
        if not admin_profile:
            return Response({"detail": "يجب اختيار حساب Admin موجود."}, status=status.HTTP_400_BAD_REQUEST)
        hub.hub_admin = admin_profile
        hub.save(update_fields=["hub_admin"])
        return Response(serializers.HubSerializer(hub, context={"request": request}).data)


class PostViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Post.objects
        .select_related("hub", "author")
        .prefetch_related("comments", "poll", "quiz")
        .order_by("-created_at")
    )
    serializer_class = serializers.PostSerializer
    permission_classes = [ReadOnlyForVisitors]

    def _approved_hub_ids(self, profile):
        if profile.role == models.Role.AGENT:
            return models.Hub.objects.values_list("id", flat=True)
        return models.HubMembership.objects.filter(
            user=profile, status=models.HubMembershipStatus.APPROVED
        ).values_list("hub_id", flat=True)

    def get_queryset(self):
        queryset = super().get_queryset()
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return queryset.none()
        queryset = queryset.filter(hub_id__in=self._approved_hub_ids(profile))
        hub_id = self.request.query_params.get("hub")
        if hub_id:
            queryset = queryset.filter(hub_id=hub_id)
        return queryset

    def perform_create(self, serializer):
        profile = self.request.user.profile
        hub = serializer.validated_data["hub"]
        if profile.role != models.Role.AGENT and not models.HubMembership.objects.filter(
            hub=hub, user=profile, status=models.HubMembershipStatus.APPROVED
        ).exists():
            raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")
        serializer.save(author=profile)


class CommentViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Comment.objects
        .select_related("post", "post__hub", "author")
        .order_by("created_at")
    )
    serializer_class = serializers.CommentSerializer
    permission_classes = [ReadOnlyForVisitors]

    def get_queryset(self):
        queryset = super().get_queryset()
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return queryset.none()
        if profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).values_list("hub_id", flat=True)
            queryset = queryset.filter(post__hub_id__in=approved)
        post_id = self.request.query_params.get("post")
        if post_id:
            queryset = queryset.filter(post_id=post_id)
        return queryset

    def perform_create(self, serializer):
        profile = self.request.user.profile
        post = serializer.validated_data["post"]
        if profile.role != models.Role.AGENT and not models.HubMembership.objects.filter(
            hub=post.hub,
            user=profile,
            status=models.HubMembershipStatus.APPROVED,
        ).exists():
            raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")
        serializer.save(author=profile)


class PollViewSet(viewsets.ModelViewSet):
    queryset = (
        models.Poll.objects
        .select_related("post", "post__hub")
        .prefetch_related("options__votes")
    )
    serializer_class = serializers.PollSerializer
    permission_classes = [ReadOnlyForVisitors]

    def get_queryset(self):
        queryset = super().get_queryset()
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return queryset.none()
        if profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).values_list("hub_id", flat=True)
            queryset = queryset.filter(post__hub_id__in=approved)
        hub_id = self.request.query_params.get("hub")
        if hub_id:
            queryset = queryset.filter(post__hub_id=hub_id)
        return queryset

    def perform_create(self, serializer):
        profile = self.request.user.profile
        post = serializer.validated_data["post"]
        if profile.role != models.Role.AGENT and not models.HubMembership.objects.filter(
            hub=post.hub, user=profile,
            status=models.HubMembershipStatus.APPROVED,
        ).exists():
            raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")
        serializer.save()


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
        .select_related("post", "post__hub")
        .prefetch_related("questions")
        .all()
    )
    serializer_class = serializers.QuizSerializer
    permission_classes = [ReadOnlyForVisitors]

    def _approved(self, profile, hub_id):
        return (
            profile.role == models.Role.AGENT
            or models.HubMembership.objects.filter(
                hub_id=hub_id,
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).exists()
        )

    def get_queryset(self):
        queryset = super().get_queryset()
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return queryset.none()
        if profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).values_list("hub_id", flat=True)
            queryset = queryset.filter(post__hub_id__in=approved)
        hub_id = self.request.query_params.get("hub")
        if hub_id:
            queryset = queryset.filter(post__hub_id=hub_id)
        return queryset

    @action(detail=False, methods=["post"], permission_classes=[IsAuthenticated], url_path="create")
    @transaction.atomic
    def create_quiz(self, request):
        profile = getattr(request.user, "profile", None)
        if profile is None:
            raise PermissionDenied("لا يوجد ملف شخصي لهذا الحساب.")

        hub_id = request.data.get("hub")
        title = str(request.data.get("title") or "").strip()
        body = str(request.data.get("body") or "").strip()
        raw_questions = request.data.get("questions") or []

        try:
            hub_id = int(hub_id)
        except (TypeError, ValueError):
            raise serializers.ValidationError({"hub": "القسم غير صالح."})

        if not title or not raw_questions:
            raise serializers.ValidationError("عنوان الاختبار والأسئلة مطلوبان.")

        if not self._approved(profile, hub_id):
            raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")

        if not isinstance(raw_questions, list) or len(raw_questions) > 30:
            raise serializers.ValidationError("عدد الأسئلة يجب أن يكون بين 1 و30.")

        hub = models.Hub.objects.filter(pk=hub_id).first()
        if hub is None:
            raise serializers.ValidationError({"hub": "القسم غير موجود."})

        post = models.Post.objects.create(
            hub=hub,
            author=profile,
            body=body or title,
            post_type="quiz",
        )
        quiz = models.Quiz.objects.create(post=post, title=title)

        for item in raw_questions:
            if not isinstance(item, dict):
                raise serializers.ValidationError("بيانات السؤال غير صالحة.")
            prompt = str(item.get("prompt") or "").strip()
            options = item.get("options")
            correct = item.get("correct_option_index")
            if (
                not prompt
                or not isinstance(options, list)
                or len(options) < 2
                or len(options) > 6
            ):
                raise serializers.ValidationError("كل سؤال يحتاج من خيارين إلى ستة خيارات.")
            try:
                correct = int(correct)
            except (TypeError, ValueError):
                raise serializers.ValidationError("الإجابة الصحيحة غير صالحة.")
            if correct < 0 or correct >= len(options):
                raise serializers.ValidationError("موضع الإجابة الصحيحة غير صالح.")
            clean_options = [str(x).strip() for x in options]
            if any(not x for x in clean_options):
                raise serializers.ValidationError("لا يمكن أن يكون خيار الاختبار فارغاً.")
            models.QuizQuestion.objects.create(
                quiz=quiz,
                prompt=prompt,
                options=clean_options,
                correct_option_index=correct,
            )

        return Response(
            serializers.QuizSerializer(quiz).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=True, methods=["post"], permission_classes=[IsAuthenticated], url_path="attempt")
    @transaction.atomic
    def attempt(self, request, pk=None):
        profile = getattr(request.user, "profile", None)
        quiz = self.get_object()

        if profile is None or not self._approved(profile, quiz.post.hub_id):
            raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")

        answers = request.data.get("answers")
        if not isinstance(answers, list):
            raise serializers.ValidationError({"answers": "يجب إرسال إجابات الأسئلة."})

        questions = list(quiz.questions.all().order_by("id"))
        if len(answers) != len(questions):
            raise serializers.ValidationError("يجب الإجابة عن جميع أسئلة الاختبار.")

        score = 0
        for question, answer in zip(questions, answers):
            try:
                answer_index = int(answer)
            except (TypeError, ValueError):
                answer_index = -1
            if answer_index == question.correct_option_index:
                score += 1

        attempt = models.QuizAttempt.objects.create(
            quiz=quiz,
            user=profile,
            score=score,
        )
        return Response({
            "id": attempt.id,
            "quiz": quiz.id,
            "score": score,
            "total": len(questions),
            "completed_at": attempt.completed_at,
        }, status=status.HTTP_201_CREATED)


class FlashcardViewSet(viewsets.ModelViewSet):
    queryset = models.Flashcard.objects.select_related("hub", "created_by").order_by("-id")
    serializer_class = serializers.FlashcardSerializer
    permission_classes = [ReadOnlyForVisitors]

    def get_queryset(self):
        queryset = super().get_queryset()
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return queryset.none()
        if profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).values_list("hub_id", flat=True)
            queryset = queryset.filter(hub_id__in=approved)
        hub_id = self.request.query_params.get("hub")
        if hub_id:
            queryset = queryset.filter(hub_id=hub_id)
        return queryset

    def perform_create(self, serializer):
        profile = self.request.user.profile
        hub = serializer.validated_data["hub"]
        if profile.role != models.Role.AGENT and not models.HubMembership.objects.filter(
            hub=hub, user=profile, status=models.HubMembershipStatus.APPROVED
        ).exists():
            raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")
        serializer.save(created_by=profile)


class ChatRoomViewSet(viewsets.ModelViewSet):
    serializer_class = serializers.ChatRoomSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = getattr(self.request.user, "profile", None)

        if profile is None:
            return models.ChatRoom.objects.none()

        rooms = (
            models.ChatRoom.objects
            .filter(participants__user=profile)
            .select_related("hub")
            .distinct()
            .order_by("-created_at")
        )
        if profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).values_list("hub_id", flat=True)
            rooms = rooms.filter(
                Q(hub__isnull=True) | Q(hub_id__in=approved)
            )
        return rooms

    @transaction.atomic
    def perform_create(self, serializer):
        profile = self.request.user.profile
        hub = serializer.validated_data.get("hub")

        if hub is not None and profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                hub=hub,
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).exists()
            if not approved:
                raise PermissionDenied("يجب قبول عضويتك في هذا القسم أولاً.")

        room = serializer.save()
        models.ChatParticipant.objects.get_or_create(room=room, user=profile)


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


class WikiPageViewSet(viewsets.ModelViewSet):
    queryset = (
        models.WikiPage.objects
        .select_related("hub", "created_by", "updated_by")
        .order_by("-updated_at")
    )
    serializer_class = serializers.WikiPageSerializer
    permission_classes = [ReadOnlyForVisitors]

    def get_queryset(self):
        queryset = super().get_queryset()
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return queryset.none()

        if profile.role != models.Role.AGENT:
            approved = models.HubMembership.objects.filter(
                user=profile,
                status=models.HubMembershipStatus.APPROVED,
            ).values_list("hub_id", flat=True)
            queryset = queryset.filter(hub_id__in=approved)

        hub_id = self.request.query_params.get("hub")
        if hub_id:
            queryset = queryset.filter(hub_id=hub_id)
        return queryset

    def perform_create(self, serializer):
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            raise PermissionDenied("لا يوجد ملف شخصي لهذا الحساب.")
        serializer.save(
            created_by=profile,
            updated_by=profile,
        )

    def perform_update(self, serializer):
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            raise PermissionDenied("لا يوجد ملف شخصي لهذا الحساب.")

        instance = self.get_object()
        if (
            instance.created_by_id != profile.id
            and profile.role not in (models.Role.ADMIN, models.Role.AGENT)
        ):
            raise PermissionDenied(
                "يمكن لمنشئ الصفحة أو المسؤول فقط تعديلها."
            )

        serializer.save(updated_by=profile)

    def perform_destroy(self, instance):
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            raise PermissionDenied("لا يوجد ملف شخصي لهذا الحساب.")

        if (
            instance.created_by_id != profile.id
            and profile.role not in (models.Role.ADMIN, models.Role.AGENT)
        ):
            raise PermissionDenied(
                "يمكن لمنشئ الصفحة أو المسؤول فقط حذفها."
            )

        instance.delete()


class ContentReportViewSet(viewsets.ModelViewSet):
    serializer_class = serializers.ContentReportSerializer

    def get_permissions(self):
        if self.action == "create":
            return [IsAuthenticated()]
        return [IsAdminOrAgent()]

    def get_queryset(self):
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return models.ContentReport.objects.none()

        return (
            models.ContentReport.objects
            .select_related("reporter", "resolved_by", "post", "comment")
            .order_by("-created_at")
        )

    def perform_create(self, serializer):
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            raise PermissionDenied("لا يوجد ملف شخصي لهذا الحساب.")

        post = serializer.validated_data.get("post")
        comment = serializer.validated_data.get("comment")

        if (post is None) == (comment is None):
            raise serializers.ValidationError(
                "يجب تحديد منشور أو تعليق واحد فقط للإبلاغ عنه."
            )

        serializer.save(reporter=profile)

    def perform_update(self, serializer):
        profile = self.request.user.profile
        serializer.save(
            resolved_by=profile,
        )


class UserBadgeViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = serializers.UserBadgeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        profile = getattr(self.request.user, "profile", None)
        if profile is None:
            return models.UserBadge.objects.none()

        queryset = (
            models.UserBadge.objects
            .select_related("user", "badge")
            .order_by("-awarded_at")
        )

        if profile.role not in (models.Role.ADMIN, models.Role.AGENT):
            queryset = queryset.filter(user=profile)

        user_id = self.request.query_params.get("user")
        if user_id and profile.role in (models.Role.ADMIN, models.Role.AGENT):
            queryset = queryset.filter(user_id=user_id)

        return queryset

    @action(detail=False, methods=["post"], permission_classes=[IsAdminOrAgent])
    def award(self, request):
        user_id = request.data.get("user")
        badge_id = request.data.get("badge")

        if not user_id or not badge_id:
            return Response(
                {"detail": "user و badge مطلوبان."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = models.User.objects.filter(pk=user_id).first()
        badge = models.Badge.objects.filter(pk=badge_id).first()

        if user is None:
            return Response(
                {"detail": "المستخدم غير موجود."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if badge is None:
            return Response(
                {"detail": "الشارة غير موجودة."},
                status=status.HTTP_404_NOT_FOUND,
            )

        user_badge, created = models.UserBadge.objects.get_or_create(
            user=user,
            badge=badge,
        )

        return Response(
            serializers.UserBadgeSerializer(user_badge).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class AdminUserViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = serializers.UserProfileSerializer
    permission_classes = [IsAgent]

    def get_queryset(self):
        return models.User.objects.select_related("user").order_by("display_name")

    @action(detail=True, methods=["post"])
    def promote(self, request, pk=None):
        profile = self.get_object()

        if profile.role == models.Role.AGENT:
            return Response(
                {"detail": "لا يمكن تعديل صلاحية Agent من هذا المسار."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile.role = models.Role.ADMIN
        profile.save(update_fields=["role"])

        return Response(serializers.UserProfileSerializer(profile).data)

    @action(detail=True, methods=["post"])
    def demote(self, request, pk=None):
        profile = self.get_object()

        if profile.role == models.Role.AGENT:
            return Response(
                {"detail": "لا يمكن تخفيض صلاحية Agent."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile.role = models.Role.MEMBER
        profile.save(update_fields=["role"])

        models.AdminPermissionGrant.objects.filter(user=profile).delete()

        return Response(serializers.UserProfileSerializer(profile).data)


class PermissionGrantViewSet(viewsets.ModelViewSet):
    queryset = (
        models.AdminPermissionGrant.objects
        .select_related("user", "user__user")
        .order_by("-granted_at")
    )
    serializer_class = serializers.AdminPermissionGrantSerializer
    permission_classes = [IsAgent]

    def perform_create(self, serializer):
        user = serializer.validated_data["user"]

        if user.role != models.Role.ADMIN:
            raise serializers.ValidationError(
                "يمكن منح هذه الصلاحيات للمسؤولين فقط."
            )

        serializer.save()

    def perform_update(self, serializer):
        user = serializer.instance.user

        if user.role != models.Role.ADMIN:
            raise serializers.ValidationError(
                "يمكن تعديل صلاحيات المسؤولين فقط."
            )

        serializer.save()


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
