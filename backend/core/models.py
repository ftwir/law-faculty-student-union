"""
core/models.py
Law Faculty Student Union — community models.
"""

import uuid
from django.conf import settings
from django.db import models


class Role(models.TextChoices):
    AGENT = "agent", "Agent (Super Admin)"
    ADMIN = "admin", "Administrator (Union Board)"
    MEMBER = "member", "Member (Law Student)"
    VISITOR = "visitor", "Visitor (Read-only)"


class User(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="profile")
    student_id = models.CharField(max_length=32, unique=True, null=True, blank=True)
    role = models.CharField(max_length=16, choices=Role.choices, default=Role.MEMBER)
    display_name = models.CharField(max_length=64)
    avatar_url = models.URLField(blank=True)
    bio = models.TextField(blank=True)
    academic_year = models.CharField(max_length=32, blank=True)
    points = models.PositiveIntegerField(default=0)
    level = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.display_name


class HubPermission(models.TextChoices):
    MANAGE_USERS = "manage_users", "Manage Users"
    MANAGE_HUBS = "manage_hubs", "Manage Hubs"
    MODERATE_CONTENT = "moderate_content", "Moderate Content"
    SEND_ANNOUNCEMENTS = "send_announcements", "Send Announcements"
    MANAGE_EVENTS = "manage_events", "Manage Events"


class AdminPermissionGrant(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="permission_grants")
    permission = models.CharField(max_length=32, choices=HubPermission.choices)
    granted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "permission")


class Hub(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True)
    description = models.TextField(blank=True)
    cover_image_url = models.URLField(blank=True)
    is_public = models.BooleanField(default=False)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    hub_admin = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="managed_hubs",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class HubMembershipRole(models.TextChoices):
    LEADER = "leader", "Hub Leader"
    MODERATOR = "moderator", "Hub Moderator"
    MEMBER = "member", "Hub Member"


class HubMembershipStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


class HubMembership(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="hub_memberships")
    role = models.CharField(max_length=16, choices=HubMembershipRole.choices, default=HubMembershipRole.MEMBER)
    status = models.CharField(
        max_length=16,
        choices=HubMembershipStatus.choices,
        default=HubMembershipStatus.PENDING,
    )
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("hub", "user")


class Post(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="posts")
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name="posts")
    body = models.TextField()
    image_url = models.URLField(blank=True)
    post_type = models.CharField(max_length=16, default="post")
    created_at = models.DateTimeField(auto_now_add=True)
    is_pinned = models.BooleanField(default=False)


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
    options = models.JSONField(help_text="List of option strings")


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


class WikiPage(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, related_name="wiki_pages")
    title = models.CharField(max_length=160)
    slug = models.SlugField()
    summary = models.TextField(blank=True)
    content = models.TextField()
    cover_image_url = models.URLField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name="wiki_pages_created")
    updated_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name="wiki_pages_updated")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("hub", "slug")
        ordering = ("-updated_at",)


class ContentReport(models.Model):
    STATUS_CHOICES = (
        ("open", "Open"),
        ("reviewing", "Reviewing"),
        ("resolved", "Resolved"),
        ("dismissed", "Dismissed"),
    )
    reporter = models.ForeignKey(User, on_delete=models.CASCADE, related_name="reports_created")
    post = models.ForeignKey(Post, on_delete=models.CASCADE, null=True, blank=True, related_name="reports")
    comment = models.ForeignKey(Comment, on_delete=models.CASCADE, null=True, blank=True, related_name="reports")
    reason = models.TextField()
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default="open")
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="reports_resolved")


class ChatRoom(models.Model):
    hub = models.ForeignKey(Hub, on_delete=models.CASCADE, null=True, blank=True, related_name="chat_rooms")
    name = models.CharField(max_length=100, blank=True)
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
    body = models.TextField(blank=True)
    attachment = models.FileField(upload_to="chat_attachments/%Y/%m/", blank=True, null=True)
    attachment_name = models.CharField(max_length=255, blank=True)
    attachment_type = models.CharField(max_length=100, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    read_by = models.ManyToManyField(User, related_name="read_messages", blank=True)


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
