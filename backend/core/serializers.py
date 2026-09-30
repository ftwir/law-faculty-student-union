from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction

from rest_framework import serializers

from . import models


DjangoUser = get_user_model()


class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = models.User
        fields = [
            "id", "username", "student_id", "role", "display_name",
            "avatar_url", "bio", "academic_year", "points", "level", "created_at",
        ]
        read_only_fields = [
            "id", "username", "role", "points", "level", "created_at",
        ]


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(min_length=3, max_length=150)
    password = serializers.CharField(write_only=True, min_length=6)
    student_id = serializers.CharField(max_length=32)
    display_name = serializers.CharField(max_length=64)

    def validate_username(self, value):
        value = value.strip()
        if DjangoUser.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("اسم المستخدم مستخدم بالفعل.")
        return value

    def validate_student_id(self, value):
        value = value.strip()
        if models.User.objects.filter(student_id=value).exists():
            raise serializers.ValidationError("الرقم الجامعي مستخدم بالفعل.")
        return value

    def validate_display_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("الاسم مطلوب.")
        return value

    @transaction.atomic
    def create(self, validated_data):
        try:
            django_user = DjangoUser.objects.create_user(
                username=validated_data["username"],
                password=validated_data["password"],
            )
            return models.User.objects.create(
                user=django_user,
                student_id=validated_data["student_id"],
                display_name=validated_data["display_name"],
            )
        except IntegrityError:
            raise serializers.ValidationError("تعذر إنشاء الحساب لأن بعض البيانات مستخدمة بالفعل.")


class HubSerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()
    membership_status = serializers.SerializerMethodField()
    is_hub_admin = serializers.SerializerMethodField()
    hub_admin_name = serializers.CharField(source="hub_admin.display_name", read_only=True)

    class Meta:
        model = models.Hub
        fields = [
            "id", "name", "slug", "description", "cover_image_url",
            "is_public", "created_by", "hub_admin", "hub_admin_name",
            "created_at", "member_count", "membership_status", "is_hub_admin",
        ]
        read_only_fields = [
            "id", "created_by", "created_at", "member_count",
            "membership_status", "is_hub_admin", "hub_admin_name",
        ]

    def get_member_count(self, obj):
        return obj.memberships.filter(
            status=models.HubMembershipStatus.APPROVED
        ).count()

    def get_membership_status(self, obj):
        request = self.context.get("request")
        profile = getattr(getattr(request, "user", None), "profile", None)
        if profile is None:
            return None
        membership = obj.memberships.filter(user=profile).first()
        return membership.status if membership else None

    def get_is_hub_admin(self, obj):
        request = self.context.get("request")
        profile = getattr(getattr(request, "user", None), "profile", None)
        return bool(
            profile and (
                profile.role == models.Role.AGENT
                or obj.hub_admin_id == profile.id
            )
        )


class HubMembershipSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.display_name", read_only=True)

    class Meta:
        model = models.HubMembership
        fields = ["id", "hub", "user", "user_name", "role", "status", "joined_at"]
        read_only_fields = ["id", "user_name", "joined_at"]


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.display_name", read_only=True)

    class Meta:
        model = models.Comment
        fields = ["id", "post", "parent", "author", "author_name", "body", "created_at"]
        read_only_fields = ["id", "author", "author_name", "created_at"]


class PollOptionSerializer(serializers.ModelSerializer):
    vote_count = serializers.SerializerMethodField()

    class Meta:
        model = models.PollOption
        fields = ["id", "text", "vote_count"]

    def get_vote_count(self, obj):
        return obj.votes.count()


class PollSerializer(serializers.ModelSerializer):
    options = PollOptionSerializer(many=True, read_only=True)

    class Meta:
        model = models.Poll
        fields = ["id", "post", "question", "closes_at", "options"]


class QuizQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.QuizQuestion
        fields = ["id", "prompt", "options", "correct_option_index"]
        extra_kwargs = {"correct_option_index": {"write_only": True}}


class QuizSerializer(serializers.ModelSerializer):
    questions = QuizQuestionSerializer(many=True, read_only=True)

    class Meta:
        model = models.Quiz
        fields = ["id", "post", "title", "questions"]


class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.display_name", read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    poll = PollSerializer(read_only=True)
    quiz = QuizSerializer(read_only=True)

    class Meta:
        model = models.Post
        fields = [
            "id", "hub", "author", "author_name", "body", "image_url",
            "post_type", "created_at", "is_pinned", "comments", "poll", "quiz",
        ]
        read_only_fields = ["id", "author", "author_name", "created_at", "comments", "poll", "quiz"]


class FlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Flashcard
        fields = ["id", "hub", "front_text", "back_text", "created_by"]
        read_only_fields = ["id", "created_by"]


class WikiPageSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source="created_by.display_name", read_only=True)
    updated_by_name = serializers.CharField(source="updated_by.display_name", read_only=True)

    class Meta:
        model = models.WikiPage
        fields = [
            "id", "hub", "title", "slug", "summary", "content", "cover_image_url",
            "created_by", "created_by_name", "updated_by", "updated_by_name",
            "created_at", "updated_at",
        ]
        read_only_fields = [
            "id", "created_by", "created_by_name", "updated_by",
            "updated_by_name", "created_at", "updated_at",
        ]


class ChatRoomSerializer(serializers.ModelSerializer):
    participant_count = serializers.SerializerMethodField()

    class Meta:
        model = models.ChatRoom
        fields = ["id", "hub", "name", "is_direct_message", "created_at", "participant_count"]
        read_only_fields = ["id", "created_at", "participant_count"]

    def get_participant_count(self, obj):
        return obj.participants.count()


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.display_name", read_only=True)

    class Meta:
        model = models.Message
        fields = ["id", "room", "sender", "sender_name", "body", "sent_at"]
        read_only_fields = ["id", "sender", "sender_name", "sent_at"]


class BadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Badge
        fields = ["id", "name", "description", "icon_url", "points_required"]


class UserBadgeSerializer(serializers.ModelSerializer):
    badge_name = serializers.CharField(source="badge.name", read_only=True)

    class Meta:
        model = models.UserBadge
        fields = ["id", "badge", "badge_name", "awarded_at"]


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Notification
        fields = ["id", "kind", "payload", "is_read", "created_at"]
        read_only_fields = ["id", "created_at"]


class ContentReportSerializer(serializers.ModelSerializer):
    reporter_name = serializers.CharField(source="reporter.display_name", read_only=True)

    class Meta:
        model = models.ContentReport
        fields = [
            "id", "reporter", "reporter_name", "post", "comment",
            "reason", "status", "created_at", "resolved_by",
        ]
        read_only_fields = ["id", "reporter", "reporter_name", "created_at", "resolved_by"]


class AdminPermissionGrantSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.user.username", read_only=True)

    class Meta:
        model = models.AdminPermissionGrant
        fields = ["id", "user", "username", "permission", "granted_at"]
        read_only_fields = ["id", "username", "granted_at"]
