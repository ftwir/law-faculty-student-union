"""
core/models.py
Law Faculty Student Union — fresh Django project
Covers: roles & permissions, Hubs (communities), posts with interactive
content (polls, quizzes, flashcards), chat, and a gamification layer.

Assumes Django 5.x + PostgreSQL. Add this app ("core") to INSTALLED_APPS.
"""

import uuid
from django.conf import settings
from django.db import models
from django.utils import timezone


# ---------------------------------------------------------------------------
# 1. Users & Roles
# ---------------------------------------------------------------------------

class Role(models.TextChoices):
    AGENT = "agent", "Agent (Super Admin)"
    ADMIN = "admin", "Administrator (Union Board)"
    MEMBER = "member", "Member (Law Student)"
    VISITOR = "visitor", "Visitor (Read-only)"


class User(models.Model):
    """
    Extend your actual auth user (e.g. AbstractUser) with these fields,
    or keep this as a OneToOne profile attached to settings.AUTH_USER_MODEL.
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="profile"
    )
    student_id = models.CharField(max_length=32, unique=True, null=True, blank=True)
    role = models.CharField(max_length=16, choices=Role.choices, default=Role.MEMBER)
    display_name = models.CharField(max_length=64)
    avatar_url = models.URLField(blank=True)
    points = models.PositiveIntegerField(default=0)
    level = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.display_name


class HubPermission(models.TextChoices):
    """Fine-grained, togglable permissions for Administrators (per platform, not per hub)."""
    MANAGE_USERS = "manage_users", "Manage Users"
    MANAGE_HUBS = "manage_hubs", "Manage Hubs"
    MODERATE_CONTENT = "moderate_content", "Moderate Content"
    SEND_ANNOUNCEMENTS = "send_announcements", "Send Announcements"
    MANAGE_EVENTS = "manage_events", "Manage Events"


class AdminPermissionGrant(models.Model):
    """Lets the Agent toggle specific permissions per Administrator."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="permission_grants")
    permission = models.CharField(max_length=32, choices=HubPermission.choices)
    granted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "permission")


# ---------------------------------------------------------------------------
# 2. Hubs (communities/clubs) & membership
# ---------------------------------------------------------------------------

class Hub(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True)
    description = models.TextField(blank=True)
    cover_image_url = models.URLField(blank=True)
    is_public = models.BooleanField(default=True)  # False = members must request to join
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class HubMembershipRole(models.TextChoices):
    LEADER = "leader", "Hub Leader"
    MODERATOR = "moderator", "Hub Moderator"
    MEMBER = "member", "Hub Member"


class HubMembership(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="hub_memberships")
    role = models.CharField(max_length=16, choices=HubMembershipRole.choices, default=HubMembershipRole.MEMBER)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("hub", "user")


# ---------------------------------------------------------------------------
# 3. Posts & interactive content
# ---------------------------------------------------------------------------

class Post(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="posts")
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name="posts")
    body = models.TextField()
    image_url = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_pinned = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.author.display_name}: {self.body[:40]}"


class Comment(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="comments")
    parent = models.ForeignKey("self", null=True, blank=True, on_delete=models.CASCADE, related_name="replies")
    author = models.ForeignKey(User, on_delete=models.CASCADE)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)


class Poll(models.Model):
    post = models.OneToOneField(Post, on_delete=models.CASCADE, related_name="poll")
    question = models.CharField(max_length=255)
    closes_at = models.DateTimeField(null=True, blank=True)


class PollOption(models.Model):
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE, related_name="options")
    text = models.CharField(max_length=120)


class PollVote(models.Model):
    option = models.ForeignKey(PollOption, on_delete=models.CASCADE, related_name="votes")
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    voted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("option", "user")


class Quiz(models.Model):
    post = models.OneToOneField(Post, on_delete=models.CASCADE, related_name="quiz")
    title = models.CharField(max_length=150)


class QuizQuestion(models.Model):
    quiz = models.ForeignKey(Quiz, on_delete=models.CASCADE, related_name="questions")
    prompt = models.TextField()
    correct_option_index = models.PositiveSmallIntegerField()
    options = models.JSONField(help_text="List of option strings, e.g. ['A', 'B', 'C', 'D']")


class QuizAttempt(models.Model):
    quiz = models.ForeignKey(Quiz, on_delete=models.CASCADE, related_name="attempts")
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    score = models.PositiveSmallIntegerField()
    completed_at = models.DateTimeField(auto_now_add=True)


class Flashcard(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="flashcards")
    front_text = models.TextField()
    back_text = models.TextField()
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)


# ---------------------------------------------------------------------------
# 4. Chat
# ---------------------------------------------------------------------------

class ChatRoom(models.Model):
    """A chat room can belong to a Hub (group chat) or be a 1:1 DM (hub=None)."""
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, null=True, blank=True, related_name="chat_rooms")
    name = models.CharField(max_length=100, blank=True)  # blank for DMs
    is_direct_message = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)


class ChatParticipant(models.Model):
    room = models.ForeignKey(ChatRoom, on_delete=models.CASCADE, related_name="participants")
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("room", "user")


class Message(models.Model):
    room = models.ForeignKey(ChatRoom, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    body = models.TextField()
    sent_at = models.DateTimeField(auto_now_add=True)
    read_by = models.ManyToManyField(User, related_name="read_messages", blank=True)


# ---------------------------------------------------------------------------
# 5. Gamification
# ---------------------------------------------------------------------------

class Badge(models.Model):
    name = models.CharField(max_length=80)
    description = models.TextField(blank=True)
    icon_url = models.URLField(blank=True)
    points_required = models.PositiveIntegerField(default=0)


class UserBadge(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="badges")
    badge = models.ForeignKey(Badge, on_delete=models.CASCADE)
    awarded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "badge")


# ---------------------------------------------------------------------------
# 6. Notifications
# ---------------------------------------------------------------------------

class Notification(models.Model):
    class Kind(models.TextChoices):
        MENTION = "mention", "Mention"
        ANNOUNCEMENT = "announcement", "Announcement"
        BADGE_AWARDED = "badge_awarded", "Badge Awarded"
        CHAT_MESSAGE = "chat_message", "New Chat Message"

    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    kind = models.CharField(max_length=20, choices=Kind.choices)
    payload = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
