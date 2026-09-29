from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction

from rest_framework import serializers

from . import models


DjangoUser = get_user_model()


class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(
        source="user.username",
        read_only=True,
    )

    class Meta:
        model = models.User

        fields = [
            "id",
            "username",
            "student_id",
            "role",
            "display_name",
            "avatar_url",
            "points",
            "level",
            "created_at",
        ]

        read_only_fields = [
            "id",
            "username",
            "role",
            "points",
            "level",
            "created_at",
        ]


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(
        min_length=3,
        max_length=150,
    )

    password = serializers.CharField(
        write_only=True,
        min_length=6,
    )

    student_id = serializers.CharField(
        max_length=32,
    )

    display_name = serializers.CharField(
        max_length=64,
    )

    def validate_username(self, value):
        value = value.strip()

        if DjangoUser.objects.filter(
            username__iexact=value
        ).exists():
            raise serializers.ValidationError(
                "اسم المستخدم مستخدم بالفعل."
            )

        return value

    def validate_student_id(self, value):
        value = value.strip()

        if models.User.objects.filter(
            student_id=value
        ).exists():
            raise serializers.ValidationError(
                "الرقم الجامعي مستخدم بالفعل."
            )

        return value

    def validate_display_name(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                "الاسم مطلوب."
            )

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
            raise serializers.ValidationError(
                "تعذر إنشاء الحساب لأن بعض البيانات مستخدمة بالفعل."
            )


class HubSerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = models.Hub

        fields = [
            "id",
            "name",
            "slug",
            "description",
            "cover_image_url",
            "is_public",
            "created_by",
            "created_at",
            "member_count",
        ]

        read_only_fields = [
            "id",
            "created_by",
            "created_at",
            "member_count",
        ]

    def get_member_count(self, obj):
        return obj.memberships.count()


class HubMembershipSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.HubMembership

        fields = [
            "id",
            "hub",
            "user",
            "role",
            "joined_at",
        ]

        read_only_fields = [
            "id",
            "joined_at",
        ]


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(
        source="author.display_name",
        read_only=True,
    )

    class Meta:
        model = models.Comment

        fields = [
            "id",
            "post",
            "parent",
            "author",
            "author_name",
            "body",
            "created_at",
        ]

        read_only_fields = [
            "id",
            "author",
            "author_name",
            "created_at",
        ]


class PollOptionSerializer(serializers.ModelSerializer):
    vote_count = serializers.SerializerMethodField()

    class Meta:
        model = models.PollOption

        fields = [
            "id",
            "text",
            "vote_count",
        ]

    def get_vote_count(self, obj):
        return obj.votes.count()


class PollSerializer(serializers.ModelSerializer):
    options = PollOptionSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = models.Poll

        fields = [
            "id",
            "post",
            "question",
            "closes_at",
            "options",
        ]


class QuizQuestionSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.QuizQuestion

        fields = [
            "id",
            "prompt",
            "options",
            "correct_option_index",
        ]

        extra_kwargs = {
            "correct_option_index": {
                "write_only": True,
            }
        }


class QuizSerializer(serializers.ModelSerializer):
    questions = QuizQuestionSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = models.Quiz

        fields = [
            "id",
            "post",
            "title",
            "questions",
        ]


class PostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(
        source="author.display_name",
        read_only=True,
    )

    comments = CommentSerializer(
        many=True,
        read_only=True,
    )

    poll = PollSerializer(
        read_only=True,
    )

    quiz = QuizSerializer(
        read_only=True,
    )

    class Meta:
        model = models.Post

        fields = [
            "id",
            "hub",
            "author",
            "author_name",
            "body",
            "image_url",
            "created_at",
            "is_pinned",
            "comments",
            "poll",
            "quiz",
        ]

        read_only_fields = [
            "id",
            "author",
            "author_name",
            "created_at",
            "comments",
            "poll",
            "quiz",
        ]


class FlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Flashcard

        fields = [
            "id",
            "hub",
            "front_text",
            "back_text",
            "created_by",
        ]

        read_only_fields = [
            "id",
            "created_by",
        ]


class ChatRoomSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.ChatRoom

        fields = [
            "id",
            "hub",
            "name",
            "is_direct_message",
            "created_at",
        ]

        read_only_fields = [
            "id",
            "created_at",
        ]


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(
        source="sender.display_name",
        read_only=True,
    )

    class Meta:
        model = models.Message

        fields = [
            "id",
            "room",
            "sender",
            "sender_name",
            "body",
            "sent_at",
        ]

        read_only_fields = [
            "id",
            "sender",
            "sender_name",
            "sent_at",
        ]


class BadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Badge

        fields = [
            "id",
            "name",
            "description",
            "icon_url",
            "points_required",
        ]


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Notification

        fields = [
            "id",
            "kind",
            "payload",
            "is_read",
            "created_at",
        ]

        read_only_fields = [
            "id",
            "created_at",
        ]
