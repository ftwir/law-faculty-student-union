from django.contrib.auth import get_user_model
from rest_framework import serializers

from . import models

DjangoUser = get_user_model()


class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = models.User
        fields = [
            "id", "username", "student_id", "role", "display_name",
            "avatar_url", "points", "level", "created_at",
        ]
        read_only_fields = ["role", "points", "level", "created_at"]


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)
    student_id = serializers.CharField()
    display_name = serializers.CharField()

    def create(self, validated_data):
        django_user = DjangoUser.objects.create_user(
            username=validated_data["username"],
            password=validated_data["password"],
        )
        return models.User.objects.create(
            user=django_user,
            student_id=validated_data["student_id"],
            display_name=validated_data["display_name"],
        )


class HubSerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = models.Hub
        fields = [
            "id", "name", "slug", "description", "cover_image_url",
            "is_public", "created_by", "created_at", "member_count",
        ]
        read_only_fields = ["created_by", "created_at"]

    def get_member_count(self, obj):
        return obj.memberships.count()


class HubMembershipSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.HubMembership
        fields = ["id", "hub", "user", "role", "joined_at"]
        read_only_fields = ["joined_at"]


class CommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source="author.display_name", read_only=True)

    class Meta:
        model = models.Comment
        fields = ["id", "post", "parent", "author", "author_name", "body", "created_at"]
        read_only_fields = ["author", "created_at"]


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
            "created_at", "is_pinned", "comments", "poll", "quiz",
        ]
        read_only_fields = ["author", "created_at"]


class FlashcardSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Flashcard
        fields = ["id", "hub", "front_text", "back_text", "created_by"]
        read_only_fields = ["created_by"]


class ChatRoomSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.ChatRoom
        fields = ["id", "hub", "name", "is_direct_message", "created_at"]
        read_only_fields = ["created_at"]


class MessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.display_name", read_only=True)

    class Meta:
        model = models.Message
        fields = ["id", "room", "sender", "sender_name", "body", "sent_at"]
        read_only_fields = ["sender", "sent_at"]


class BadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Badge
        fields = ["id", "name", "description", "icon_url", "points_required"]


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = models.Notification
        fields = ["id", "kind", "payload", "is_read", "created_at"]
        read_only_fields = ["created_at"]
